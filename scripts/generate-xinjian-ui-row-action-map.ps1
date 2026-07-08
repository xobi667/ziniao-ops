[CmdletBinding(PositionalBinding = $false)]
param(
  [string[]]$CapturePath = @(),
  [string]$CaptureDir = "",
  [string]$OutputPath = "",
  [switch]$DryRun,
  [switch]$Json
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path

if (!$CaptureDir -and (!$CapturePath -or $CapturePath.Count -eq 0)) {
  $CaptureDir = Join-Path $root ".ziniao-ops\xinjian-row-action-captures"
}
if (!$OutputPath) {
  $OutputPath = Join-Path $root "references\xinjian-ui-row-action-map.json"
}

$node = Get-Command node -ErrorAction SilentlyContinue
if (!$node) {
  $payload = [ordered]@{
    ok = $false
    error = "node_missing"
    message = "Node.js is required for Xinjian row-action map generation."
  }
  if ($Json) { $payload | ConvertTo-Json -Depth 6 } else { Write-Host $payload.message }
  exit 2
}

$helper = Join-Path $PSScriptRoot "generate-xinjian-ui-row-action-map.mjs"
if (!(Test-Path -LiteralPath $helper)) {
  $payload = [ordered]@{
    ok = $false
    error = "row_action_map_helper_missing"
    path = $helper
  }
  if ($Json) { $payload | ConvertTo-Json -Depth 6 } else { Write-Host "Missing helper: $helper" }
  exit 2
}

$argsList = @($helper, "--out", $OutputPath)
if ($CaptureDir) { $argsList += @("--capture-dir", $CaptureDir) }
foreach ($item in @($CapturePath)) {
  if ($item) { $argsList += @("--capture", $item) }
}
if ($DryRun) { $argsList += "--dry-run" }

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
    error = "row_action_map_output_parse_failed"
    exit_code = $code
    raw_output = $text
  }
}

if ($Json) {
  $parsed | ConvertTo-Json -Depth 8
} else {
  if ($parsed.ok) {
    Write-Host ("Generated Xinjian row-action map with {0} pages and {1} actions: {2}" -f $parsed.pages, $parsed.actions, $parsed.output_path)
  } else {
    Write-Host ("Xinjian row-action map generation failed: {0}" -f $parsed.error)
  }
}
exit $code
