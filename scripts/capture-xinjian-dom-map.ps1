[CmdletBinding(PositionalBinding = $false)]
param(
  [int]$Port = 9342,
  [string]$Url = "https://erp.xinjianerp.com/crm/matser/management/highSeas",
  [string]$OutputPath = "",
  [switch]$Json
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path

if (!$OutputPath) {
  $dir = Join-Path $root ".ziniao-ops\xinjian-dom-captures"
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $OutputPath = Join-Path $dir ("{0}.json" -f (Get-Date -Format "yyyyMMdd-HHmmss"))
}

$node = Get-Command node -ErrorAction SilentlyContinue
if (!$node) {
  $payload = [ordered]@{
    ok = $false
    error = "node_missing"
    message = "Node.js is required for CDP DOM capture."
  }
  if ($Json) { $payload | ConvertTo-Json -Depth 6 } else { Write-Host $payload.message }
  exit 2
}

$helper = Join-Path $PSScriptRoot "capture-xinjian-dom-cdp.mjs"
if (!(Test-Path -LiteralPath $helper)) {
  $payload = [ordered]@{
    ok = $false
    error = "capture_helper_missing"
    path = $helper
  }
  if ($Json) { $payload | ConvertTo-Json -Depth 6 } else { Write-Host "Missing helper: $helper" }
  exit 2
}

$raw = @(& node $helper --port $Port --match-url $Url --out $OutputPath 2>&1)
$code = $LASTEXITCODE
$text = ($raw | Out-String).Trim()
$parsed = $null
if ($text) {
  try { $parsed = $text | ConvertFrom-Json } catch {}
}
if (!$parsed) {
  $parsed = [pscustomobject]@{
    ok = $false
    error = "capture_output_parse_failed"
    exit_code = $code
    raw_output = $text
  }
}

if ($Json) {
  $parsed | ConvertTo-Json -Depth 14
} else {
  if ($parsed.ok) {
    Write-Host ("Captured {0} DOM controls: {1}" -f $parsed.controls_count, $parsed.output_path)
  } else {
    Write-Host ("Xinjian DOM capture failed: {0}" -f $parsed.error)
  }
}
exit $code
