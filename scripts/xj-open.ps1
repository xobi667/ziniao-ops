[CmdletBinding(PositionalBinding = $false)]
param(
  [string]$Url = "https://erp.xinjianerp.com/index/home",
  [int]$Port = 9339,
  [switch]$ForceDebuggable,
  [switch]$NormalWindow,
  [switch]$Json
)

$ErrorActionPreference = "Stop"
$script = Join-Path $PSScriptRoot "open-xinjian-login.ps1"

function ConvertFrom-JsonText($Lines) {
  $text = (($Lines | Out-String).Trim())
  if (!$text) { return $null }
  try { return $text | ConvertFrom-Json } catch { return $null }
}

$argsList = @(
  "-NoProfile",
  "-ExecutionPolicy", "Bypass",
  "-File", $script,
  "-Url", $Url,
  "-Port", [string]$Port,
  "-Json"
)
if ($ForceDebuggable) { $argsList += "-ForceDebuggable" }
if ($NormalWindow) { $argsList += "-NormalWindow" }

$raw = @(& powershell @argsList 2>&1)
$exitCode = $LASTEXITCODE
$result = ConvertFrom-JsonText $raw
if (!$result) {
  $result = [pscustomobject]@{
    ok = $false
    mode = "parse_failed"
    raw_output = ($raw | Out-String).Trim()
    next_action = "inspect_xinjian_open_output"
  }
}
$result | Add-Member -NotePropertyName "command" -NotePropertyValue "xj-open" -Force

if ($Json) {
  $result | ConvertTo-Json -Depth 12
} else {
  if ($result.ok) {
    Write-Host "XJ_OPEN_OK"
    Write-Host ("page: {0}" -f $result.matched_page_url)
    Write-Host ("kind: {0}" -f $result.matched_page_kind)
    Write-Host ("next_action: {0}" -f $result.next_action)
  } else {
    Write-Host "XJ_OPEN_BLOCKED"
    Write-Host ("next_action: {0}" -f $result.next_action)
  }
}

if ($exitCode -ne 0 -and !$result.ok) { exit $exitCode }
exit 0
