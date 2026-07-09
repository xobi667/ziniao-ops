[CmdletBinding(PositionalBinding = $false)]
param(
  [string[]]$StoreName = @(),
  [string[]]$InputPath = @(),
  [string[]]$SearchRoot = @(),
  [int]$Days = 7,
  [string]$StartDate = "",
  [string]$EndDate = "",
  [string]$OutputPath = "",
  [string]$ExcelOutputPath = "",
  [string]$BrowserBridgeScriptPath = "",
  [int[]]$Port = @(),
  [string]$Url = "https://erp.xinjianerp.com/index/home",
  [switch]$ProbeEndpoint,
  [switch]$NoBrowserFetch,
  [switch]$AllowLocalFallback,
  [switch]$NoAutoOpen,
  [switch]$ForceOpen,
  [switch]$ZiniaoOnly,
  [switch]$Json
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$analyzer = Join-Path $PSScriptRoot "analyze-xinjian-ad-hourly.py"
$StoreName = @(
  foreach ($name in $StoreName) {
    if ($name) {
      $name -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    }
  }
)

if (!(Test-Path -LiteralPath $analyzer)) {
  throw "Analyzer not found: $analyzer"
}
if (!$BrowserBridgeScriptPath) {
  $BrowserBridgeScriptPath = Join-Path $PSScriptRoot "xinjian-ziniao-bridge.ps1"
}

function Get-ResultProperty {
  param(
    [object]$Object,
    [string]$Name,
    [object]$Default = $null
  )
  if ($Object -and $Object.PSObject.Properties.Match($Name).Count -gt 0) {
    return $Object.$Name
  }
  return $Default
}

function Get-ResultArray {
  param(
    [object]$Object,
    [string]$Name
  )
  $value = Get-ResultProperty -Object $Object -Name $Name -Default @()
  if ($null -eq $value) {
    return @()
  }
  return @($value | ForEach-Object { $_ } | Where-Object { $null -ne $_ -and [string]$_ -ne "" })
}

function ConvertFrom-JsonText($Lines) {
  $text = (($Lines | Out-String).Trim())
  if (!$text) { return $null }
  try { return $text | ConvertFrom-Json } catch { return $null }
}

function Get-BrowserFetchVerified($Result) {
  if (!$Result) { return $false }
  if ($Result.PSObject.Properties.Match("real_data_verified").Count -gt 0) {
    return [bool]$Result.real_data_verified
  }
  if ($Result.PSObject.Properties.Match("result").Count -gt 0 -and $Result.result -and $Result.result.PSObject.Properties.Match("real_data_verified").Count -gt 0) {
    return [bool]$Result.result.real_data_verified
  }
  return $false
}

function Get-BrowserFetchUiVerified($Result) {
  if (!$Result) { return $false }
  if ($Result.PSObject.Properties.Match("ui_interaction_verified").Count -gt 0) {
    return [bool]$Result.ui_interaction_verified
  }
  if ($Result.PSObject.Properties.Match("result").Count -gt 0 -and $Result.result -and $Result.result.PSObject.Properties.Match("ui_interaction_verified").Count -gt 0) {
    return [bool]$Result.result.ui_interaction_verified
  }
  if ($Result.PSObject.Properties.Match("data_source").Count -gt 0 -and
    $Result.data_source -and
    $Result.data_source.PSObject.Properties.Match("evidence").Count -gt 0 -and
    $Result.data_source.evidence -and
    $Result.data_source.evidence.PSObject.Properties.Match("ui_interaction_verified").Count -gt 0) {
    return [bool]$Result.data_source.evidence.ui_interaction_verified
  }
  return $false
}

function Get-BrowserFetchProperty($Result, [string]$Name) {
  if (!$Result) { return $null }
  if ($Result.PSObject.Properties.Match($Name).Count -gt 0) {
    return $Result.$Name
  }
  if ($Result.PSObject.Properties.Match("result").Count -gt 0 -and $Result.result -and $Result.result.PSObject.Properties.Match($Name).Count -gt 0) {
    return $Result.result.$Name
  }
  return $null
}

function Invoke-BrowserPageFetch {
  if (!(Test-Path -LiteralPath $BrowserBridgeScriptPath)) {
    return [pscustomobject]@{
      ok = $false
      error = "browser_bridge_script_missing"
      path = $BrowserBridgeScriptPath
      next_action = "repair_missing_xinjian_browser_bridge"
    }
  }

  $bridgeArgs = @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    $BrowserBridgeScriptPath,
    "-StoreName",
    ($StoreName -join ","),
    "-Days",
    [string]$Days,
    "-Url",
    $Url,
    "-OutputPath",
    $OutputPath,
    "-ExcelOutputPath",
    $ExcelOutputPath,
    "-Json"
  )
  if ($StartDate) { $bridgeArgs += @("-StartDate", $StartDate) }
  if ($EndDate) { $bridgeArgs += @("-EndDate", $EndDate) }
  foreach ($item in @($Port | Where-Object { $_ -gt 0 } | Sort-Object -Unique)) {
    $bridgeArgs += @("-Port", [string]$item)
  }
  if ($NoAutoOpen) { $bridgeArgs += "-NoAutoOpen" }
  if ($ForceOpen) { $bridgeArgs += "-ForceOpen" }
  if ($ZiniaoOnly) { $bridgeArgs += "-ZiniaoOnly" }

  $raw = @(& powershell @bridgeArgs 2>&1)
  $parsed = ConvertFrom-JsonText $raw
  if ($parsed) { return $parsed }
  return [pscustomobject]@{
    ok = $false
    error = "browser_bridge_output_parse_failed"
    raw_output = ($raw | Out-String).Trim()
    next_action = "inspect_xinjian_browser_bridge_output"
  }
}

if (!$SearchRoot -or $SearchRoot.Count -eq 0) {
  $workspaceParent = Split-Path -Parent $root
  $userDataRoot = Split-Path -Parent $workspaceParent
  $SearchRoot = @(
    $root,
    (Join-Path ([Environment]::GetFolderPath("UserProfile")) "Downloads"),
    (Join-Path $userDataRoot "Downloads")
  ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }
}

if (!$EndDate) {
  $EndDate = (Get-Date).ToString("yyyy-MM-dd")
}
if (!$StartDate) {
  $StartDate = (Get-Date).Date.AddDays(-1 * ([Math]::Max($Days, 1) - 1)).ToString("yyyy-MM-dd")
}

if (!$OutputPath) {
  $reportDir = Join-Path $root "reports.local"
  New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $OutputPath = Join-Path $reportDir "$stamp-xinjian-ad-hourly.md"
} elseif (![System.IO.Path]::IsPathRooted($OutputPath)) {
  $OutputPath = Join-Path $root $OutputPath
}
if (!$ExcelOutputPath) {
  if ([System.IO.Path]::GetExtension($OutputPath).ToLowerInvariant() -eq ".xlsx") {
    $ExcelOutputPath = $OutputPath
    $OutputPath = [System.IO.Path]::ChangeExtension($OutputPath, ".md")
  } else {
    $ExcelOutputPath = [System.IO.Path]::ChangeExtension($OutputPath, ".xlsx")
  }
} elseif (![System.IO.Path]::IsPathRooted($ExcelOutputPath)) {
  $ExcelOutputPath = Join-Path $root $ExcelOutputPath
}

$browserFetch = $null
$hasInputPath = @($InputPath | Where-Object { $_ }).Count -gt 0
if (!$NoBrowserFetch -and !$hasInputPath) {
  $browserFetch = Invoke-BrowserPageFetch
  $browserUiVerified = Get-BrowserFetchUiVerified $browserFetch
  $browserVerified = (Get-BrowserFetchVerified $browserFetch) -and $browserUiVerified
  if ($browserVerified) {
    $payload = [ordered]@{
      ok = $true
      mode = "browser_page_fetch"
      real_data_verified = $true
      ui_interaction_verified = $browserUiVerified
      ui_interaction = Get-BrowserFetchProperty -Result $browserFetch -Name "ui_interaction"
      browser_fetch = $browserFetch
      data_source = Get-BrowserFetchProperty -Result $browserFetch -Name "data_source"
      analysis = Get-BrowserFetchProperty -Result $browserFetch -Name "analysis"
      output = Get-BrowserFetchProperty -Result $browserFetch -Name "output"
      excel_output = Get-BrowserFetchProperty -Result $browserFetch -Name "excel_output"
      next_action = Get-BrowserFetchProperty -Result $browserFetch -Name "next_action"
    }
    if ($Json) {
      $payload | ConvertTo-Json -Depth 16
    } else {
      Write-Host "XINJIAN_AD_HOURLY_BROWSER_OK"
      Write-Host "Excel: $($payload.excel_output)"
    }
    exit 0
  }

  if (!$AllowLocalFallback) {
    $payload = [ordered]@{
      ok = $false
      mode = "browser_page_required"
      real_data_verified = $false
      browser_fetch = $browserFetch
      data_source = [ordered]@{
        type = "none"
        verified = $false
        evidence = [ordered]@{
          browser_bridge_attempted = $true
          browser_next_action = Get-BrowserFetchProperty -Result $browserFetch -Name "next_action"
          ui_interaction_verified = $browserUiVerified
          ui_interaction = Get-BrowserFetchProperty -Result $browserFetch -Name "ui_interaction"
        }
        rejected_sources = @(
          "api_only_without_verified_ui_click",
          "stale_local_export_without_explicit_input",
          "window_detection",
          "uia_action_catalog",
          "route_map",
          "button_memory",
          "browser_title_only"
        )
      }
      output = $null
      excel_output = $null
      local_fallback_skipped = $true
      next_action = if (Get-BrowserFetchProperty -Result $browserFetch -Name "next_action") {
        Get-BrowserFetchProperty -Result $browserFetch -Name "next_action"
      } else {
        "open_or_login_real_xinjian_page_then_rerun"
      }
    }
    if ($Json) {
      $payload | ConvertTo-Json -Depth 16
    } else {
      Write-Host "XINJIAN_AD_HOURLY_BROWSER_REQUIRED"
      Write-Host "Open or log in to the real Xinjian page, then rerun the same command."
    }
    exit 0
  }
}

$endpointProbe = $null
if ($ProbeEndpoint) {
  $body = @{
    shopIds = @()
    startTime = "$StartDate 00:00:00"
    endTime = "$EndDate 23:59:59"
    dateType = 1
    currencyType = 1
  } | ConvertTo-Json -Depth 6
  try {
    $response = Invoke-WebRequest -UseBasicParsing `
      -Uri "https://erp.xinjianerp.com/prod-api/erp/ad/data/summary-by-date_v2" `
      -Method POST `
      -ContentType "application/json;charset=UTF-8" `
      -Body $body `
      -TimeoutSec 15
    $content = $response.Content | ConvertFrom-Json
    $endpointProbe = [ordered]@{
      ok = ($content.code -eq 0 -or $content.code -eq 200)
      http_status = $response.StatusCode
      code = $content.code
      msg = $content.msg
      login_required = ($content.code -eq 401)
    }
  } catch {
    $endpointProbe = [ordered]@{
      ok = $false
      http_status = $null
      code = $null
      msg = $_.Exception.Message
      login_required = $false
    }
  }
}

$python = Get-Command python -ErrorAction SilentlyContinue
if (!$python) {
  throw "python command not found"
}

$argsList = @(
  $analyzer,
  "--start-date", $StartDate,
  "--end-date", $EndDate,
  "--days", "$Days",
  "--output", $OutputPath,
  "--xlsx-output", $ExcelOutputPath,
  "--json"
)
foreach ($store in $StoreName) {
  if ($store) {
    $argsList += @("--store", $store)
  }
}
foreach ($path in $InputPath) {
  if ($path) {
    $resolved = (Resolve-Path -LiteralPath $path).Path
    $argsList += @("--input", $resolved)
  }
}
if (!$InputPath -or $InputPath.Count -eq 0) {
  foreach ($path in $SearchRoot) {
    if ($path) {
      $argsList += @("--search-root", $path)
    }
  }
}

$raw = & python @argsList
$exit = $LASTEXITCODE
$analysis = $null
try {
  $analysis = ($raw | Out-String | ConvertFrom-Json)
} catch {
  $analysis = [pscustomobject]@{
    ok = $false
    parse_failed = $true
    raw = ($raw | Out-String)
  }
}
$analysisOutput = $null
$analysisExcelOutput = $null
if ($analysis -and $analysis.PSObject.Properties.Match("output").Count -gt 0) {
  $analysisOutput = $analysis.output
}
if ($analysis -and $analysis.PSObject.Properties.Match("xlsx_output").Count -gt 0) {
  $analysisExcelOutput = $analysis.xlsx_output
}

$analysisOk = [bool](Get-ResultProperty -Object $analysis -Name "ok" -Default $false)
$analysisRecordCount = [int](Get-ResultProperty -Object $analysis -Name "record_count" -Default 0)
$analysisFilesUsed = @(Get-ResultArray -Object $analysis -Name "files_used")
$analysisSourceTypes = @(Get-ResultArray -Object $analysis -Name "source_types")
$realDataVerified = [bool]($analysisOk -and $analysisRecordCount -gt 0 -and $analysisFilesUsed.Count -gt 0)
$dataSourceType = if ($analysisSourceTypes.Count -eq 1) {
  [string]$analysisSourceTypes[0]
} elseif ($analysisSourceTypes.Count -gt 1) {
  "mixed_input_files"
} else {
  "none"
}

$result = [ordered]@{
  ok = $analysisOk
  real_data_verified = $realDataVerified
  endpoint_probe = $endpointProbe
  data_source = [ordered]@{
    type = $dataSourceType
    verified = $realDataVerified
    evidence = [ordered]@{
      record_count = $analysisRecordCount
      files_used = @($analysisFilesUsed)
      source_types = @($analysisSourceTypes)
      output = $analysisOutput
      excel_output = $analysisExcelOutput
    }
    rejected_sources = @(
      "window_detection",
      "uia_action_catalog",
      "route_map",
      "button_memory",
      "browser_title_only"
    )
  }
  analysis = $analysis
  output = $analysisOutput
  excel_output = $analysisExcelOutput
  next_action = $null
}

if (!$result.ok) {
  if ($endpointProbe -and $endpointProbe.login_required) {
    $result.next_action = "login_or_export_required"
  } else {
    $result.next_action = "provide_hourly_export_or_enable_browser"
  }
}

if ($Json) {
  $result | ConvertTo-Json -Depth 12
} else {
  if ($result.ok) {
    Write-Host "XINJIAN_AD_HOURLY_OK"
    Write-Host "Report: $analysisOutput"
    Write-Host "Excel: $analysisExcelOutput"
  } else {
    Write-Host "XINJIAN_AD_HOURLY_BLOCKED"
    if ($endpointProbe -and $endpointProbe.login_required) {
      Write-Host "Xinjian endpoint requires login: $($endpointProbe.msg)"
    }
    Write-Host "No analyzable local hourly export was found. Provide an hourly product-ad export, or sign in through the in-app browser when available."
  }
}

if ($exit -ne 0 -and $Json) {
  exit 0
}
exit $exit
