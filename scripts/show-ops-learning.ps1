param(
  [string]$StatePath = "",
  [int]$Last = 20,
  [switch]$Json
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
if (!$StatePath) {
  $StatePath = Join-Path $root ".ziniao-ops\ops-learning.local.json"
}

if (!(Test-Path -LiteralPath $StatePath)) {
  $result = [ordered]@{ ok = $true; path = $StatePath; items = @(); count = 0 }
  if ($Json) { $result | ConvertTo-Json -Depth 6 } else { Write-Host "No local learning records yet." }
  exit 0
}

$data = Get-Content -LiteralPath $StatePath -Raw -Encoding UTF8 | ConvertFrom-Json
$items = @($data.items | Select-Object -Last $Last)
$result = [ordered]@{
  ok = $true
  path = (Resolve-Path -LiteralPath $StatePath).Path
  count = @($data.items).Count
  items = $items
}

if ($Json) {
  $result | ConvertTo-Json -Depth 8
} else {
  foreach ($item in $items) {
    Write-Host ("[{0}] {1} {2}" -f $item.at, $item.kind, $item.intent)
    if ($item.problem) { Write-Host ("  problem: {0}" -f $item.problem) }
    if ($item.fix) { Write-Host ("  fix: {0}" -f $item.fix) }
  }
}
