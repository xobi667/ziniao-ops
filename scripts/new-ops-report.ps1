param(
  [string]$Store = "",
  [string]$Platform = "",
  [string]$View = "overview",
  [string]$Status = "draft",
  [string]$TimeRange = "",
  [string]$Workflow = "",
  [string]$TaskPath = "",
  [string]$MetricsJson = "",
  [string[]]$Findings = @(),
  [string[]]$Risks = @(),
  [string[]]$Recommendations = @(),
  [string[]]$Actions = @(),
  [string[]]$Blockers = @(),
  [string]$OutputPath = "",
  [switch]$Json
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path

if (!$Store) { $Store = "UNKNOWN_STORE" }
if (!$TimeRange) { $TimeRange = "visible page / current account timezone" }
if (!$Workflow) { $Workflow = $View }
if (!$OutputPath) {
  $reportDir = Join-Path $root "reports.local"
  New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
  $safeStore = ($Store -replace "[^A-Za-z0-9_.-]+", "_").Trim("_")
  if (!$safeStore) { $safeStore = "store" }
  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $OutputPath = Join-Path $reportDir ("{0}-{1}-{2}.md" -f $stamp, $safeStore, $View)
} elseif (![System.IO.Path]::IsPathRooted($OutputPath)) {
  $OutputPath = Join-Path $root $OutputPath
}

$metricsBlock = if ($MetricsJson) { $MetricsJson.Trim() } else { "{}" }
$findingsText = if ($Findings.Count -gt 0) { ($Findings | ForEach-Object { "- $_" }) -join "`r`n" } else { "- Not recorded" }
$risksText = if ($Risks.Count -gt 0) { ($Risks | ForEach-Object { "- $_" }) -join "`r`n" } else { "- None recorded" }
$recommendationsText = if ($Recommendations.Count -gt 0) { ($Recommendations | ForEach-Object { "- $_" }) -join "`r`n" } else { "- None recorded" }
$actionsText = if ($Actions.Count -gt 0) { ($Actions | ForEach-Object { "- $_" }) -join "`r`n" } else { "- None recorded" }
$blockersText = if ($Blockers.Count -gt 0) { ($Blockers | ForEach-Object { "- $_" }) -join "`r`n" } else { "- None" }
$taskLine = if ($TaskPath) { "- Task file: $TaskPath`r`n" } else { "" }

$content = @"
# Ziniao Ops Report

- Store: $Store
- Platform: $Platform
- View: $View
- Workflow: $Workflow
- Time range: $TimeRange
- Status: $Status
$taskLine- Generated at: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## Summary Findings

$findingsText

## Risks

$risksText

## Recommendations

$recommendationsText

## Visible Metrics

````json
$metricsBlock
````

## Actions Taken

$actionsText

## Blockers

$blockersText

## Safety Notes

- This report is based on visible seller pages or explicitly provided local data.
- Do not include passwords, verification codes, browser session data, cookies, tokens, or private keys.
- Do not claim a module was checked unless it was actually opened or read.
"@

$parent = Split-Path -Parent $OutputPath
if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
$content | Set-Content -LiteralPath $OutputPath -Encoding UTF8

$result = [ordered]@{
  ok = $true
  path = (Resolve-Path -LiteralPath $OutputPath).Path
  store = $Store
  platform = $Platform
  view = $View
  workflow = $Workflow
  status = $Status
}

if ($Json) {
  $result | ConvertTo-Json -Depth 6
} else {
  Write-Host ("Report written: {0}" -f $result.path)
}
