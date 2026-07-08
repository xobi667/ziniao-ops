[CmdletBinding(PositionalBinding = $false)]
param(
  [int]$Port = 9342,
  [string]$Url = "https://erp.xinjianerp.com/index/home",
  [string]$OutputPath = "",
  [int]$MaxTables = 12,
  [int]$MaxRowsPerTable = 20,
  [int]$WaitMs = 8000,
  [switch]$Json
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path

if (!$OutputPath) {
  $dir = Join-Path $root ".ziniao-ops\xinjian-row-action-captures"
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $safe = "page"
  try {
    $uri = [uri]$Url
    $safe = $uri.AbsolutePath.Trim("/") -replace "[^A-Za-z0-9._-]+", "_"
    if (!$safe) { $safe = "root" }
    if ($safe.Length -gt 80) { $safe = $safe.Substring(0, 80) }
  } catch {
  }
  $OutputPath = Join-Path $dir ("{0}-{1}.json" -f (Get-Date -Format "yyyyMMdd-HHmmss"), $safe)
}

$node = Get-Command node -ErrorAction SilentlyContinue
if (!$node) {
  $payload = [ordered]@{
    ok = $false
    error = "node_missing"
    message = "Node.js is required for CDP row-action capture."
  }
  if ($Json) { $payload | ConvertTo-Json -Depth 6 } else { Write-Host $payload.message }
  exit 2
}

$helper = Join-Path $PSScriptRoot "capture-xinjian-row-actions-cdp.mjs"
if (!(Test-Path -LiteralPath $helper)) {
  $payload = [ordered]@{
    ok = $false
    error = "row_action_capture_helper_missing"
    path = $helper
  }
  if ($Json) { $payload | ConvertTo-Json -Depth 6 } else { Write-Host "Missing helper: $helper" }
  exit 2
}

$argsList = @($helper, "--port", [string]$Port, "--match-url", $Url, "--out", $OutputPath, "--max-tables", [string]$MaxTables, "--max-rows-per-table", [string]$MaxRowsPerTable, "--wait-ms", [string]$WaitMs)
$raw = @(& node @argsList 2>&1)
$code = $LASTEXITCODE
$text = ($raw | Out-String).Trim()
$parsed = $null
if ($text) {
  try { $parsed = $text | ConvertFrom-Json } catch {}
}
if (!$parsed) {
  $parsed = [pscustomobject]@{
    ok = $false
    error = "row_action_capture_output_parse_failed"
    exit_code = $code
    raw_output = $text
  }
}

if ($Json) {
  $parsed | ConvertTo-Json -Depth 14
} else {
  if ($parsed.ok) {
    Write-Host ("Captured {0} tables and {1} row actions: {2}" -f $parsed.counts.tables, $parsed.counts.row_actions, $parsed.output_path)
  } else {
    Write-Host ("Xinjian row-action capture failed: {0}" -f $parsed.error)
  }
}
exit $code
