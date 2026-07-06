param(
  [string]$Root = "",
  [string]$Category = "",
  [int]$TimeoutSec = 15,
  [switch]$Json
)

$ErrorActionPreference = "Continue"

if (!$Root) {
  $Root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
} else {
  $Root = (Resolve-Path -LiteralPath $Root).Path
}

$mapPath = Join-Path $Root "references\ecommerce-capability-map.json"
$externalPath = Join-Path $Root "references\external-tools.json"
$checkedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

try {
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls
} catch {
}

function Read-JsonFile([string]$Path) {
  if (!(Test-Path -LiteralPath $Path)) { return $null }
  try {
    return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json)
  } catch {
    return [pscustomobject]@{ _parse_error = $_.Exception.Message }
  }
}

function Add-Target {
  param(
    [System.Collections.ArrayList]$Targets,
    [string]$Id,
    [string]$Name,
    [string]$CategoryName,
    [string]$Kind,
    [string]$Url,
    [string]$Status,
    [string]$Priority
  )
  if (!$Url) { return }
  if ($Category -and $CategoryName -ne $Category) { return }
  $key = ("{0}|{1}|{2}" -f $Id, $Kind, $Url).ToLowerInvariant()
  foreach ($target in $Targets) {
    if ($target.key -eq $key) { return }
  }
  [void]$Targets.Add([pscustomobject][ordered]@{
    key = $key
    id = $Id
    name = $Name
    category = $CategoryName
    kind = $Kind
    url = $Url
    configured_status = $Status
    priority = $Priority
  })
}

function Get-UrlStatus([string]$Url, [int]$Timeout) {
  $record = [ordered]@{
    reachable = $false
    status_code = 0
    final_url = $Url
    title = ""
    error = ""
  }
  try {
    $resp = Invoke-WebRequest -Uri $Url -UseBasicParsing -Method Get -TimeoutSec $Timeout
    $record.status_code = [int]$resp.StatusCode
    $record.reachable = $true
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
        $code = [int]$_.Exception.Response.StatusCode
        $record.status_code = $code
        if (($code -ge 200 -and $code -lt 400) -or $code -in @(401, 403, 405)) {
          $record.reachable = $true
        }
      }
    } catch {
    }
  }
  return [pscustomobject]$record
}

$map = Read-JsonFile $mapPath
if (!$map) {
  $result = [ordered]@{
    ok = $false
    checked_at = $checkedAt
    root = $Root
    error = "references/ecommerce-capability-map.json not found"
    targets = @()
  }
  if ($Json) { $result | ConvertTo-Json -Depth 8 } else { Write-Host "ECOMMERCE_TOOL_CHECK_FAILED: capability map not found" }
  exit 1
}
if ($map.PSObject.Properties.Name -contains "_parse_error") {
  $result = [ordered]@{
    ok = $false
    checked_at = $checkedAt
    root = $Root
    error = "Failed to parse references/ecommerce-capability-map.json: $($map._parse_error)"
    targets = @()
  }
  if ($Json) { $result | ConvertTo-Json -Depth 8 } else { Write-Host "ECOMMERCE_TOOL_CHECK_FAILED: $($result.error)" }
  exit 1
}

$targets = New-Object System.Collections.ArrayList

foreach ($platform in @($map.platforms)) {
  foreach ($url in @($platform.official_urls)) {
    Add-Target $targets ([string]$platform.id) ([string]$platform.name) "official_platform_api" "platform_url" ([string]$url) ([string]$platform.current_support) ([string]$platform.priority)
  }
  foreach ($api in @($platform.api_connectors)) {
    Add-Target $targets ([string]$api.id) ([string]$api.name) "official_platform_api" "official_url" ([string]$api.official_url) ([string]$api.status) ([string]$platform.priority)
    Add-Target $targets ([string]$api.id) ([string]$api.name) "official_platform_api" "docs_url" ([string]$api.docs_url) ([string]$api.status) ([string]$platform.priority)
    if ($api.PSObject.Properties.Name -contains "mcp_url") {
      Add-Target $targets ([string]$api.id) ([string]$api.name) "official_platform_api" "mcp_url" ([string]$api.mcp_url) ([string]$api.status) ([string]$platform.priority)
    }
  }
}

foreach ($tool in @($map.tools)) {
  Add-Target $targets ([string]$tool.id) ([string]$tool.name) ([string]$tool.category) "official_url" ([string]$tool.official_url) ([string]$tool.status) ([string]$tool.priority)
  if ($tool.PSObject.Properties.Name -contains "docs_url") {
    Add-Target $targets ([string]$tool.id) ([string]$tool.name) ([string]$tool.category) "docs_url" ([string]$tool.docs_url) ([string]$tool.status) ([string]$tool.priority)
  }
  if ($tool.PSObject.Properties.Name -contains "mcp_url") {
    Add-Target $targets ([string]$tool.id) ([string]$tool.name) ([string]$tool.category) "mcp_url" ([string]$tool.mcp_url) ([string]$tool.status) ([string]$tool.priority)
  }
}

$external = Read-JsonFile $externalPath
if ($external -and !($external.PSObject.Properties.Name -contains "_parse_error")) {
  foreach ($tool in @($external.tools)) {
    Add-Target $targets ([string]$tool.id) ([string]$tool.name) ([string]$tool.category) "external_catalog_url" ([string]$tool.official_url) ([string]$tool.install_mode) "P1"
    foreach ($propName in @("open_platform_url", "api_doc_url", "api_pricing_url", "mcp_url")) {
      if ($tool.PSObject.Properties.Name -contains $propName) {
        Add-Target $targets ([string]$tool.id) ([string]$tool.name) ([string]$tool.category) $propName ([string]$tool.$propName) ([string]$tool.install_mode) "P1"
      }
    }
  }
}

$results = @()
foreach ($target in @($targets)) {
  $status = Get-UrlStatus ([string]$target.url) $TimeoutSec
  $results += [pscustomobject][ordered]@{
    id = [string]$target.id
    name = [string]$target.name
    category = [string]$target.category
    kind = [string]$target.kind
    priority = [string]$target.priority
    configured_status = [string]$target.configured_status
    url = [string]$target.url
    reachable = [bool]$status.reachable
    status_code = [int]$status.status_code
    title = [string]$status.title
    final_url = [string]$status.final_url
    error = [string]$status.error
  }
}

$warnings = @($results | Where-Object { !$_.reachable })
$categories = @($results | Select-Object -ExpandProperty category -Unique | Sort-Object)
$result = [ordered]@{
  ok = ($warnings.Count -eq 0)
  checked_at = $checkedAt
  root = $Root
  category_filter = $Category
  total = @($results).Count
  reachable = @($results | Where-Object { $_.reachable }).Count
  warnings = @($warnings).Count
  categories = $categories
  policy = $map.policy
  targets = @($results)
}

if ($Json) {
  $result | ConvertTo-Json -Depth 10
} else {
  if ($warnings.Count -eq 0) {
    Write-Host "ECOMMERCE_TOOL_CHECK_OK"
  } else {
    Write-Host "ECOMMERCE_TOOL_CHECK_HAS_WARNINGS"
  }
  Write-Host ("Targets: {0}, reachable: {1}, warnings: {2}" -f $result.total, $result.reachable, $result.warnings)
  if ($Category) { Write-Host ("Category: {0}" -f $Category) }
  foreach ($item in $results) {
    $prefix = if ($item.reachable) { "[ok]" } else { "[warn]" }
    $statusText = if ($item.status_code) { "HTTP $($item.status_code)" } else { $item.error }
    Write-Host ("{0} {1} / {2} / {3} - {4}" -f $prefix, $item.category, $item.name, $item.kind, $statusText)
  }
}

exit 0
