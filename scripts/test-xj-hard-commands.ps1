[CmdletBinding(PositionalBinding = $false)]
param(
  [switch]$Json
)

$ErrorActionPreference = "Stop"
$failures = [System.Collections.Generic.List[object]]::new()
$scripts = @(
  "xj-status.ps1",
  "xj-open.ps1",
  "xj-ad-hourly.ps1",
  "xj-export-watch.ps1"
)

foreach ($name in $scripts) {
  $path = Join-Path $PSScriptRoot $name
  if (!(Test-Path -LiteralPath $path)) {
    [void]$failures.Add("$name missing")
    continue
  }
  try {
    $text = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
    [scriptblock]::Create($text) | Out-Null
  } catch {
    [void]$failures.Add(("{0} parse failed: {1}" -f $name, $_.Exception.Message))
  }
}

$fakeBridge = Join-Path ([System.IO.Path]::GetTempPath()) ("fake-xj-hard-command-{0}.ps1" -f ([guid]::NewGuid().ToString("N")))
$fakeBridgeText = @'
param(
  [string[]]$StoreName = @(),
  [int]$Days = 7,
  [string]$OutputPath = "",
  [string]$ExcelOutputPath = "",
  [string]$Url = "",
  [switch]$Json
)
$payload = [ordered]@{
  ok = $true
  real_data_verified = $true
  ui_interaction_verified = $true
  data_source = [ordered]@{ type = "browser_cdp_endpoint_response"; verified = $true }
  output = $OutputPath
  excel_output = $ExcelOutputPath
}
if ($Json) { $payload | ConvertTo-Json -Depth 8 } else { Write-Host "OK" }
'@

try {
  Set-Content -LiteralPath $fakeBridge -Value $fakeBridgeText -Encoding UTF8
  $raw = @(& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "xj-ad-hourly.ps1") -StoreName "DEMO" -BrowserBridgeScriptPath $fakeBridge -Json 2>&1)
  $parsed = $null
  try {
    $parsed = ($raw | Out-String | ConvertFrom-Json)
  } catch {
    [void]$failures.Add(("xj-ad-hourly JSON parse failed: {0}" -f ($raw | Out-String).Trim()))
  }
  if ($parsed) {
    if (!$parsed.ok) { [void]$failures.Add("xj-ad-hourly fake bridge did not return ok=true") }
    if ([string]$parsed.command -ne "xj-ad-hourly") { [void]$failures.Add("xj-ad-hourly command marker missing") }
  }
} finally {
  Remove-Item -LiteralPath $fakeBridge -ErrorAction SilentlyContinue
}

$payload = [ordered]@{
  ok = ($failures.Count -eq 0)
  failures = @($failures.ToArray())
}
if ($Json) {
  $payload | ConvertTo-Json -Depth 8
} else {
  if ($payload.ok) { Write-Host "XJ hard command tests passed." } else { $payload.failures | ForEach-Object { Write-Host "- $_" } }
}
if (!$payload.ok) { exit 1 }
