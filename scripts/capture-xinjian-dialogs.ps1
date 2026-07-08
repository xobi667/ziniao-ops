[CmdletBinding(PositionalBinding = $false)]
param(
  [int]$Port = 9342,
  [string]$Url = "https://erp.xinjianerp.com/index/home",
  [string]$OutputPath = "",
  [int]$MaxTriggers = 20,
  [switch]$Json
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path

if (!$OutputPath) {
  $dir = Join-Path $root ".ziniao-ops\xinjian-dialog-captures"
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
    message = "Node.js is required for CDP dialog capture."
  }
  if ($Json) { $payload | ConvertTo-Json -Depth 6 } else { Write-Host $payload.message }
  exit 2
}

$helper = Join-Path $PSScriptRoot "capture-xinjian-dialogs-cdp.mjs"
if (!(Test-Path -LiteralPath $helper)) {
  $payload = [ordered]@{
    ok = $false
    error = "dialog_capture_helper_missing"
    path = $helper
  }
  if ($Json) { $payload | ConvertTo-Json -Depth 6 } else { Write-Host "Missing helper: $helper" }
  exit 2
}

$argsList = @($helper, "--port", [string]$Port, "--match-url", $Url, "--out", $OutputPath, "--max-triggers", [string]$MaxTriggers)
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
    error = "dialog_capture_output_parse_failed"
    exit_code = $code
    raw_output = $text
  }
}

if ($Json) {
  $parsed | ConvertTo-Json -Depth 14
} else {
  if ($parsed.ok) {
    Write-Host ("Captured {0} dialog triggers and {1} dialog buttons: {2}" -f $parsed.counts.triggers, $parsed.counts.dialog_buttons, $parsed.output_path)
  } else {
    Write-Host ("Xinjian dialog capture failed: {0}" -f $parsed.error)
  }
}
exit $code
