[CmdletBinding(PositionalBinding = $false)]
param(
  [string]$OutputJsonPath = "",
  [string]$OutputMarkdownPath = "",
  [switch]$DryRun,
  [switch]$Json
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path

if (!$OutputJsonPath) {
  $OutputJsonPath = Join-Path $root "references\xinjian-ui-action-catalog.json"
}
if (!$OutputMarkdownPath) {
  $OutputMarkdownPath = Join-Path $root "references\xinjian-ui-action-catalog.md"
}

$node = Get-Command node -ErrorAction SilentlyContinue
if (!$node) {
  $payload = [ordered]@{
    ok = $false
    error = "node_missing"
    message = "Node.js is required for Xinjian action catalog generation."
  }
  if ($Json) { $payload | ConvertTo-Json -Depth 6 } else { Write-Host $payload.message }
  exit 2
}

$helper = Join-Path $PSScriptRoot "generate-xinjian-ui-action-catalog.mjs"
if (!(Test-Path -LiteralPath $helper)) {
  $payload = [ordered]@{
    ok = $false
    error = "action_catalog_helper_missing"
    path = $helper
  }
  if ($Json) { $payload | ConvertTo-Json -Depth 6 } else { Write-Host "Missing helper: $helper" }
  exit 2
}

$argsList = @(
  $helper,
  "--root", $root,
  "--out-json", $OutputJsonPath,
  "--out-md", $OutputMarkdownPath
)
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
    error = "action_catalog_generation_output_parse_failed"
    exit_code = $code
    raw_output = $text
  }
}

if ($Json) {
  $parsed | ConvertTo-Json -Depth 12
} else {
  if ($parsed.ok) {
    Write-Host ("Generated Xinjian action catalog: {0} pages, {1} actions" -f $parsed.pages, $parsed.actions)
    Write-Host ("JSON: {0}" -f $parsed.json_output_path)
    Write-Host ("Markdown: {0}" -f $parsed.markdown_output_path)
  } else {
    Write-Host ("Xinjian action catalog generation failed: {0}" -f $parsed.error)
  }
}
exit $code
