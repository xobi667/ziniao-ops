param(
  [string]$Kind = "note",
  [string]$Store = "",
  [string]$Intent = "",
  [string]$Problem = "",
  [string]$Fix = "",
  [string]$Tags = "",
  [string]$StatePath = "",
  [switch]$Json
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
. (Join-Path $PSScriptRoot "sensitive-text.ps1")
if (!$StatePath) {
  $stateDir = Join-Path $root ".ziniao-ops"
  New-Item -ItemType Directory -Force -Path $stateDir | Out-Null
  $StatePath = Join-Path $stateDir "ops-learning.local.json"
}

function ConvertTo-SafeText([string]$Value) {
  if (!$Value) { return "" }
  $text = $Value.Trim()
  return ConvertTo-ZiniaoOpsSafeText $text
}

$items = @()
if (Test-Path -LiteralPath $StatePath) {
  try {
    $existing = Get-Content -LiteralPath $StatePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $items = @($existing.items)
  } catch {
    $items = @()
  }
}

$record = [ordered]@{
  at = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  kind = ConvertTo-SafeText $Kind
  store = ConvertTo-SafeText $Store
  intent = ConvertTo-SafeText $Intent
  problem = ConvertTo-SafeText $Problem
  fix = ConvertTo-SafeText $Fix
  tags = @($Tags -split "," | ForEach-Object { ConvertTo-SafeText $_ } | Where-Object { $_ })
}

$items = @($items + [pscustomobject]$record)
if ($items.Count -gt 200) {
  $items = @($items | Select-Object -Last 200)
}

$payload = [ordered]@{
  version = 1
  note = "Local-only learning log. Do not commit. Do not store passwords, tokens, cookies, or verification codes."
  items = $items
}

$payload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $StatePath -Encoding UTF8

$result = [ordered]@{
  ok = $true
  path = (Resolve-Path -LiteralPath $StatePath).Path
  count = $items.Count
}

if ($Json) {
  $result | ConvertTo-Json -Depth 4
} else {
  Write-Host ("Learning recorded: {0}" -f $result.path)
}
