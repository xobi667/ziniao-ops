[CmdletBinding(PositionalBinding = $false)]
param(
  [int]$Port = 9342,
  [string]$Url = "https://erp.xinjianerp.com/index/home",
  [string]$OutputPath = "",
  [int]$MaxRoutes = 300,
  [switch]$Json
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path

if (!$OutputPath) {
  $dir = Join-Path $root ".ziniao-ops\xinjian-route-discovery"
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $OutputPath = Join-Path $dir ("{0}.json" -f (Get-Date -Format "yyyyMMdd-HHmmss"))
}

$node = Get-Command node -ErrorAction SilentlyContinue
if (!$node) {
  $payload = [ordered]@{
    ok = $false
    error = "node_missing"
    message = "Node.js is required for CDP route discovery."
  }
  if ($Json) { $payload | ConvertTo-Json -Depth 6 } else { Write-Host $payload.message }
  exit 2
}

$helper = Join-Path $PSScriptRoot "discover-xinjian-routes-cdp.mjs"
if (!(Test-Path -LiteralPath $helper)) {
  $payload = [ordered]@{
    ok = $false
    error = "route_discovery_helper_missing"
    path = $helper
  }
  if ($Json) { $payload | ConvertTo-Json -Depth 6 } else { Write-Host "Missing helper: $helper" }
  exit 2
}

$raw = @(& node $helper --port $Port --match-url $Url --out $OutputPath --max-routes $MaxRoutes 2>&1)
$code = $LASTEXITCODE
$text = ($raw | Out-String).Trim()
$parsed = $null
if ($text) {
  try { $parsed = $text | ConvertFrom-Json } catch {}
}
if (!$parsed) {
  $parsed = [pscustomobject]@{
    ok = $false
    error = "route_discovery_output_parse_failed"
    exit_code = $code
    raw_output = $text
  }
}

if ($Json) {
  $parsed | ConvertTo-Json -Depth 14
} else {
  if ($parsed.ok) {
    Write-Host ("Discovered {0} Xinjian routes and {1} visible links: {2}" -f $parsed.counts.routes, $parsed.counts.visible_links, $parsed.output_path)
  } else {
    Write-Host ("Xinjian route discovery failed: {0}" -f $parsed.error)
  }
}
exit $code
