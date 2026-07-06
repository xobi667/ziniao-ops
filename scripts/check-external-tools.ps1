param(
  [string]$Root = "",
  [switch]$Json
)

$ErrorActionPreference = "Continue"

if (!$Root) {
  $Root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
} else {
  $Root = (Resolve-Path -LiteralPath $Root).Path
}

$configPath = Join-Path $Root "references\external-tools.json"
$checkedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
$items = @()

function Get-UrlStatus([string]$Url) {
  $record = [ordered]@{
    reachable = $false
    status_code = 0
    final_url = $Url
    title = ""
    error = ""
  }
  if (!$Url) {
    $record.error = "missing_url"
    return [pscustomobject]$record
  }
  try {
    $resp = Invoke-WebRequest -Uri $Url -UseBasicParsing -Method Get -TimeoutSec 20
    $record.reachable = $true
    $record.status_code = [int]$resp.StatusCode
    if ($resp.BaseResponse -and $resp.BaseResponse.ResponseUri) {
      $record.final_url = [string]$resp.BaseResponse.ResponseUri.AbsoluteUri
    }
    $html = [string]$resp.Content
    $m = [regex]::Match($html, "<title[^>]*>(.*?)</title>", "IgnoreCase,Singleline")
    if ($m.Success) {
      $record.title = [System.Net.WebUtility]::HtmlDecode(($m.Groups[1].Value -replace "\s+", " ").Trim())
    }
  } catch {
    $record.error = $_.Exception.Message
    try {
      if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
        $record.status_code = [int]$_.Exception.Response.StatusCode
      }
    } catch {
    }
  }
  [pscustomobject]$record
}

function Get-LinkFoxSkillVersion([string]$Html, [string]$SkillName) {
  if (!$Html -or !$SkillName) { return "" }
  $escaped = [regex]::Escape($SkillName)
  $match = [regex]::Match($Html, "($escaped)(?s:.{0,500}?)(v\d+(?:\.\d+){1,3})", "IgnoreCase")
  if ($match.Success) { return [string]$match.Groups[2].Value }
  return ""
}

if (!(Test-Path -LiteralPath $configPath)) {
  $result = [ordered]@{
    ok = $false
    checked_at = $checkedAt
    root = $Root
    error = "references/external-tools.json not found"
    tools = @()
  }
  if ($Json) { $result | ConvertTo-Json -Depth 8 } else { Write-Host "EXTERNAL_TOOL_CHECK_FAILED: references/external-tools.json not found" }
  exit 1
}

try {
  $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
} catch {
  $result = [ordered]@{
    ok = $false
    checked_at = $checkedAt
    root = $Root
    error = "Failed to parse references/external-tools.json: $($_.Exception.Message)"
    tools = @()
  }
  if ($Json) { $result | ConvertTo-Json -Depth 8 } else { Write-Host "EXTERNAL_TOOL_CHECK_FAILED: $($result.error)" }
  exit 1
}

$catalogCache = @{}
foreach ($tool in @($config.tools)) {
  $url = [string]$tool.official_url
  $status = $null
  $html = ""
  if ($url) {
    $status = Get-UrlStatus $url
    if ($status.reachable -and ([string]$tool.check_mode) -match "linkfox_skill_version|html_title_and_skill_versions") {
      try {
        $html = [string](Invoke-WebRequest -Uri $url -UseBasicParsing -Method Get -TimeoutSec 20).Content
      } catch {
        $html = ""
      }
    }
  }

  $version = ""
  if ([string]$tool.skill_catalog_name) {
    $version = Get-LinkFoxSkillVersion $html ([string]$tool.skill_catalog_name)
  }

  $extraUrls = @()
  foreach ($propName in @("open_platform_url", "api_doc_url", "api_pricing_url", "mcp_url")) {
    if ($tool.PSObject.Properties.Name -contains $propName) {
      $extraUrl = [string]$tool.$propName
      if ($extraUrl) {
        $extraStatus = Get-UrlStatus $extraUrl
        $extraUrls += [pscustomobject]@{
          name = $propName
          url = $extraUrl
          reachable = [bool]$extraStatus.reachable
          status_code = [int]$extraStatus.status_code
          title = [string]$extraStatus.title
          error = [string]$extraStatus.error
        }
      }
    }
  }

  $items += [pscustomobject][ordered]@{
    id = [string]$tool.id
    name = [string]$tool.name
    category = [string]$tool.category
    url = $url
    reachable = if ($status) { [bool]$status.reachable } else { $false }
    status_code = if ($status) { [int]$status.status_code } else { 0 }
    title = if ($status) { [string]$status.title } else { "" }
    detected_version = $version
    install_mode = [string]$tool.install_mode
    requires_account = [bool]$tool.requires_account
    auto_install_supported = [bool]$tool.auto_install_supported
    auto_update_supported = [bool]$tool.auto_update_supported
    adoption = [string]$tool.adoption
    extra_urls = $extraUrls
    error = if ($status) { [string]$status.error } else { "missing_url" }
  }
}

$hasErrors = @($items | Where-Object { !$_.reachable }).Count -gt 0
$result = [ordered]@{
  ok = !$hasErrors
  checked_at = $checkedAt
  root = $Root
  policy = $config.policy
  tools = @($items)
}

if ($Json) {
  $result | ConvertTo-Json -Depth 10
} else {
  if ($result.ok) { Write-Host "EXTERNAL_TOOL_CHECK_OK" } else { Write-Host "EXTERNAL_TOOL_CHECK_HAS_WARNINGS" }
  foreach ($item in $items) {
    $version = if ($item.detected_version) { " $($item.detected_version)" } else { "" }
    if ($item.reachable) {
      Write-Host ("[ok] {0}{1} - {2}" -f $item.name, $version, $item.url)
    } else {
      Write-Host ("[warn] {0} - {1}" -f $item.name, $item.error)
    }
    if (!$item.auto_install_supported) {
      Write-Host ("      install: manual/explicit setup required ({0})" -f $item.install_mode)
    }
  }
}

exit 0
