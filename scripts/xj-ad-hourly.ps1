[CmdletBinding(PositionalBinding = $false)]
param(
  [string[]]$StoreName = @(),
  [int]$Days = 7,
  [string]$StartDate = "",
  [string]$EndDate = "",
  [string]$OutputPath = "",
  [string]$ExcelOutputPath = "",
  [string]$Url = "https://erp.xinjianerp.com/index/home",
  [int[]]$Port = @(),
  [string]$BrowserBridgeScriptPath = "",
  [switch]$NoAutoOpen,
  [switch]$ForceOpen,
  [switch]$ZiniaoOnly,
  [switch]$Json
)

$ErrorActionPreference = "Stop"
$script = Join-Path $PSScriptRoot "xinjian-erp-ad-hourly.ps1"

function ConvertFrom-JsonText($Lines) {
  $text = (($Lines | Out-String).Trim())
  if (!$text) { return $null }
  try { return $text | ConvertFrom-Json } catch { return $null }
}

$argsList = @(
  "-NoProfile",
  "-ExecutionPolicy", "Bypass",
  "-File", $script,
  "-StoreName", ($StoreName -join ","),
  "-Days", [string]$Days,
  "-Url", $Url,
  "-Json"
)
if ($StartDate) { $argsList += @("-StartDate", $StartDate) }
if ($EndDate) { $argsList += @("-EndDate", $EndDate) }
if ($OutputPath) { $argsList += @("-OutputPath", $OutputPath) }
if ($ExcelOutputPath) { $argsList += @("-ExcelOutputPath", $ExcelOutputPath) }
if ($BrowserBridgeScriptPath) { $argsList += @("-BrowserBridgeScriptPath", $BrowserBridgeScriptPath) }
foreach ($item in @($Port | Where-Object { $_ -gt 0 } | Sort-Object -Unique)) {
  $argsList += @("-Port", [string]$item)
}
if ($NoAutoOpen) { $argsList += "-NoAutoOpen" }
if ($ForceOpen) { $argsList += "-ForceOpen" }
if ($ZiniaoOnly) { $argsList += "-ZiniaoOnly" }

$raw = @(& powershell @argsList 2>&1)
$exitCode = $LASTEXITCODE
$result = ConvertFrom-JsonText $raw
if (!$result) {
  $result = [pscustomobject]@{
    ok = $false
    mode = "parse_failed"
    raw_output = ($raw | Out-String).Trim()
    next_action = "inspect_xinjian_ad_hourly_output"
  }
}
$result | Add-Member -NotePropertyName "command" -NotePropertyValue "xj-ad-hourly" -Force

if ($Json) {
  $result | ConvertTo-Json -Depth 16
} else {
  if ($result.ok -and $result.real_data_verified -and $result.ui_interaction_verified) {
    Write-Host "XJ_AD_HOURLY_OK"
    Write-Host ("Excel: {0}" -f $result.excel_output)
    Write-Host ("Report: {0}" -f $result.output)
  } else {
    Write-Host "XJ_AD_HOURLY_BLOCKED"
    Write-Host ("next_action: {0}" -f $result.next_action)
    if ($result.login_state) { Write-Host ("login_state: {0}" -f $result.login_state) }
    if ($result.stores_not_found) { Write-Host ("stores_not_found: {0}" -f (@($result.stores_not_found) -join ", ")) }
  }
}

if ($exitCode -ne 0 -and !$result.ok) { exit $exitCode }
exit 0
