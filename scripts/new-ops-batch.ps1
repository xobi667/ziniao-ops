[CmdletBinding(PositionalBinding = $false)]
param(
  [string]$InputCsv = "",
  [string[]]$Store = @(),
  [string]$Workflow = "daily_check",
  [string]$Platform = "",
  [string]$OutputPath = "",
  [switch]$Json,
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$AdditionalStore = @()
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$taskScript = Join-Path $PSScriptRoot "new-ops-task.ps1"

function ConvertTo-SafeFileName([string]$Value) {
  $safe = ($Value -replace "[^A-Za-z0-9_.-]+", "_").Trim("_")
  if (!$safe) { return "ops-batch" }
  return $safe
}

function Read-StoreRowsFromCsv([string]$Path) {
  if (!(Test-Path -LiteralPath $Path)) { throw "CSV not found: $Path" }
  $rows = Import-Csv -LiteralPath $Path
  $items = @()
  foreach ($row in @($rows)) {
    $name = ""
    foreach ($field in @("store", "Store", "name", "Name", "店铺", "店铺名称")) {
      $prop = $row.PSObject.Properties[$field]
      if ($prop -and $prop.Value) {
        $name = [string]$prop.Value
        break
      }
    }
    if (!$name) { continue }
    $rowPlatform = $Platform
    foreach ($field in @("platform", "Platform", "平台")) {
      $prop = $row.PSObject.Properties[$field]
      if (!$rowPlatform -and $prop -and $prop.Value) {
        $rowPlatform = [string]$prop.Value
      }
    }
    $items += [pscustomobject]@{ store = $name; platform = $rowPlatform }
  }
  return $items
}

$items = @()
if ($InputCsv) {
  $csvPath = if ([System.IO.Path]::IsPathRooted($InputCsv)) { $InputCsv } else { Join-Path $root $InputCsv }
  $items += @(Read-StoreRowsFromCsv $csvPath)
}
foreach ($storeName in @($Store)) {
  if ($storeName) {
    $items += [pscustomobject]@{ store = $storeName; platform = $Platform }
  }
}
foreach ($storeName in @($AdditionalStore)) {
  if ($storeName) {
    $items += [pscustomobject]@{ store = $storeName; platform = $Platform }
  }
}

if ($items.Count -eq 0) {
  throw "No stores provided. Use -Store or -InputCsv."
}

if (!$OutputPath) {
  $batchDir = Join-Path $root "reports.local\batches"
  New-Item -ItemType Directory -Force -Path $batchDir | Out-Null
  $OutputPath = Join-Path $batchDir ("{0}-{1}.md" -f (Get-Date -Format "yyyyMMdd-HHmmss"), (ConvertTo-SafeFileName $Workflow))
} elseif (![System.IO.Path]::IsPathRooted($OutputPath)) {
  $OutputPath = Join-Path $root $OutputPath
}

$taskResults = @()
foreach ($item in $items) {
  $taskArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $taskScript, "-Store", ([string]$item.store), "-Workflow", $Workflow, "-Json")
  if ($item.platform) {
    $taskArgs += @("-Platform", ([string]$item.platform))
  }
  $taskJson = @(& powershell @taskArgs 2>&1)
  if ($LASTEXITCODE -ne 0) {
    throw (($taskJson | Out-String).Trim())
  }
  $taskResults += (($taskJson | Out-String).Trim() | ConvertFrom-Json)
}

$lines = @()
$lines += "# Ziniao Ops Batch"
$lines += ""
$lines += "- Workflow: $Workflow"
$lines += "- Stores: $($taskResults.Count)"
$lines += "- Generated at: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")"
$lines += ""
$lines += "## Store Tasks"
$lines += ""
foreach ($task in $taskResults) {
  $lines += "### $($task.store)"
  $lines += ""
  $lines += "- Platform: $($task.platform)"
  $lines += "- Task file: $($task.path)"
  $lines += "- Views: $((@($task.views) -join ', '))"
  $lines += "- First command: $(@($task.open_commands)[0])"
  $lines += ""
}
$lines += "## Safety"
$lines += ""
$lines += "- Review this batch before opening stores."
$lines += "- Do not run destructive seller actions."
$lines += "- Stop on login, verification, permission, or ambiguous store match."

$parent = Split-Path -Parent $OutputPath
if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
($lines -join "`r`n") | Set-Content -LiteralPath $OutputPath -Encoding UTF8

$result = [ordered]@{
  ok = $true
  path = (Resolve-Path -LiteralPath $OutputPath).Path
  workflow = $Workflow
  stores_count = $taskResults.Count
  tasks = @($taskResults)
}

if ($Json) {
  $result | ConvertTo-Json -Depth 10
} else {
  Write-Host ("Batch written: {0}" -f $result.path)
  Write-Host ("Stores: {0}" -f $result.stores_count)
}
