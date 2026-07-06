param(
  [string]$Store = "",
  [string]$Intent = "overview",
  [string]$Platform = "",
  [string]$TimeRange = "",
  [string]$Workflow = "",
  [string]$OutputPath = "",
  [switch]$Json
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
. (Join-Path $PSScriptRoot "powershell-utils.ps1")
$workflowPath = Join-Path $root "references\ops-workflows.json"

function ConvertTo-SafeFileName([string]$Value) {
  $safe = ($Value -replace "[^A-Za-z0-9_.-]+", "_").Trim("_")
  if (!$safe) { return "ops-task" }
  return $safe
}

function Join-MarkdownList([string[]]$Items) {
  if (!$Items -or $Items.Count -eq 0) { return "- None" }
  return (($Items | ForEach-Object { "- $_" }) -join "`r`n")
}

function Find-Workflow($Config, [string]$WorkflowId, [string]$Text) {
  $workflows = @($Config.workflows)
  if ($WorkflowId) {
    $match = $workflows | Where-Object { $_.id -eq $WorkflowId } | Select-Object -First 1
    if ($match) { return $match }
    throw "Unknown workflow id: $WorkflowId"
  }

  $needle = " $Text ".ToLowerInvariant()
  foreach ($wf in $workflows) {
    foreach ($phrase in @($wf.phrases)) {
      if ($phrase -and $needle.Contains(([string]$phrase).ToLowerInvariant())) {
        return $wf
      }
    }
  }

  $fallback = $workflows | Where-Object { $_.id -eq "overview" } | Select-Object -First 1
  return $fallback
}

if (!(Test-Path -LiteralPath $workflowPath)) {
  throw "Workflow definition not found: $workflowPath"
}

$config = [System.IO.File]::ReadAllText($workflowPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
$workflowObj = Find-Workflow $config $Workflow $Intent
if (!$Store) { $Store = "UNKNOWN_STORE" }
if (!$TimeRange) { $TimeRange = "visible page / current account timezone" }

$views = @($workflowObj.views | ForEach-Object { [string]$_ })
$metrics = @($workflowObj.required_metrics | ForEach-Object { [string]$_ })
$questions = @($workflowObj.questions | ForEach-Object { [string]$_ })
$safeRules = @($config.safe_rules | ForEach-Object { [string]$_ })

if (!$OutputPath) {
  $taskDir = Join-Path $root "reports.local\tasks"
  New-Item -ItemType Directory -Force -Path $taskDir | Out-Null
  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $OutputPath = Join-Path $taskDir ("{0}-{1}-{2}.md" -f $stamp, (ConvertTo-SafeFileName $Store), $workflowObj.id)
} elseif (![System.IO.Path]::IsPathRooted($OutputPath)) {
  $OutputPath = Join-Path $root $OutputPath
}

$openCommands = @()
foreach ($view in $views) {
  $openCommands += ".\open-store.ps1 $(ConvertTo-ZiniaoOpsPowerShellLiteral $Store) -View $(ConvertTo-ZiniaoOpsPowerShellLiteral $view)"
}
$reportCommand = ".\scripts\new-ops-report.ps1 -Store $(ConvertTo-ZiniaoOpsPowerShellLiteral $Store) -Platform $(ConvertTo-ZiniaoOpsPowerShellLiteral $Platform) -View $(ConvertTo-ZiniaoOpsPowerShellLiteral ([string]$workflowObj.id)) -TimeRange $(ConvertTo-ZiniaoOpsPowerShellLiteral $TimeRange) -MetricsJson '{}'"

$content = @"
# Ziniao Ops Task

- Store: $Store
- Platform: $Platform
- Workflow: $($workflowObj.id) / $($workflowObj.name)
- Intent: $Intent
- Time range: $TimeRange
- Generated at: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## Open Sequence

$(Join-MarkdownList $openCommands)

## Views To Check

$(Join-MarkdownList $views)

## Metrics To Read

$(Join-MarkdownList $metrics)

## Questions To Answer

$(Join-MarkdownList $questions)

## Safety Rules

$(Join-MarkdownList $safeRules)

## Report Command

````powershell
$reportCommand
````
"@

$parent = Split-Path -Parent $OutputPath
if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
$content | Set-Content -LiteralPath $OutputPath -Encoding UTF8

$result = [ordered]@{
  ok = $true
  path = (Resolve-Path -LiteralPath $OutputPath).Path
  store = $Store
  platform = $Platform
  workflow = $workflowObj.id
  workflow_name = $workflowObj.name
  views = $views
  required_metrics = $metrics
  questions = $questions
  open_commands = $openCommands
}

if ($Json) {
  $result | ConvertTo-Json -Depth 8
} else {
  Write-Host ("Task written: {0}" -f $result.path)
  Write-Host ("Workflow: {0}" -f $result.workflow)
  Write-Host ("First command: {0}" -f $openCommands[0])
}
