[CmdletBinding(PositionalBinding = $false)]
param(
  [string[]]$StoreName = @(),
  [int]$Days = 7,
  [string]$StartDate = "",
  [string]$EndDate = "",
  [string]$WatchRoot = "",
  [int]$TimeoutSec = 300,
  [string]$OutputPath = "",
  [string]$ExcelOutputPath = "",
  [switch]$Json
)

$ErrorActionPreference = "Stop"
$script = Join-Path $PSScriptRoot "wait-xinjian-export.ps1"

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
  "-TimeoutSec", [string]$TimeoutSec,
  "-Json"
)
if ($StartDate) { $argsList += @("-StartDate", $StartDate) }
if ($EndDate) { $argsList += @("-EndDate", $EndDate) }
if ($WatchRoot) { $argsList += @("-WatchRoot", $WatchRoot) }
if ($OutputPath) { $argsList += @("-OutputPath", $OutputPath) }
if ($ExcelOutputPath) { $argsList += @("-ExcelOutputPath", $ExcelOutputPath) }

$raw = @(& powershell @argsList 2>&1)
$exitCode = $LASTEXITCODE
$result = ConvertFrom-JsonText $raw
if (!$result) {
  $result = [pscustomobject]@{
    ok = $false
    mode = "parse_failed"
    raw_output = ($raw | Out-String).Trim()
    next_action = "inspect_export_watch_output"
  }
}
$result | Add-Member -NotePropertyName "command" -NotePropertyValue "xj-export-watch" -Force

if ($Json) {
  $result | ConvertTo-Json -Depth 14
} else {
  if ($result.ok) {
    Write-Host "XJ_EXPORT_WATCH_OK"
    Write-Host ("file: {0}" -f $result.file)
    Write-Host ("Excel: {0}" -f $result.excel_output)
  } else {
    Write-Host "XJ_EXPORT_WATCH_BLOCKED"
    Write-Host ("next_action: {0}" -f $result.next_action)
  }
}

if ($exitCode -ne 0 -and !$result.ok) { exit $exitCode }
exit 0
