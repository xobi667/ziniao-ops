[CmdletBinding(PositionalBinding = $false)]
param(
  [string]$CatalogPath = "",
  [string]$LiveCoveragePath = "",
  [string]$ExerciseReportPath = "",
  [string]$OutputJsonPath = "",
  [string]$OutputMarkdownPath = "",
  [switch]$Json
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
if (!$CatalogPath) { $CatalogPath = Join-Path $root "references\xinjian-ui-action-catalog.json" }
if (!$LiveCoveragePath) { $LiveCoveragePath = Join-Path $root "references\xinjian-ui-live-button-coverage.json" }
if (!$ExerciseReportPath) { $ExerciseReportPath = Join-Path $root "references\xinjian-ui-action-exercise-report.json" }
if (!$OutputJsonPath) { $OutputJsonPath = Join-Path $root "references\xinjian-ui-rpa-readiness.json" }
if (!$OutputMarkdownPath) { $OutputMarkdownPath = Join-Path $root "references\xinjian-ui-rpa-readiness.md" }

function Read-JsonFile([string]$Path) {
  if (!$Path -or !(Test-Path -LiteralPath $Path)) { return $null }
  try {
    return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
  } catch {
    return $null
  }
}

function Get-ObjectCount($Value) {
  if ($null -eq $Value) { return 0 }
  return @($Value).Count
}

function Get-PropertyValue($Object, [string]$Name, $Fallback = $null) {
  if ($null -eq $Object) { return $Fallback }
  if ($Object.PSObject.Properties.Match($Name).Count -eq 0) { return $Fallback }
  $value = $Object.$Name
  if ($null -eq $value) { return $Fallback }
  return $value
}

$catalog = Read-JsonFile $CatalogPath
if (!$catalog) {
  $payload = [ordered]@{
    ok = $false
    error = "catalog_missing_or_invalid"
    catalog_path = $CatalogPath
  }
  if ($Json) { $payload | ConvertTo-Json -Depth 6 } else { Write-Host "Catalog missing or invalid: $CatalogPath" }
  exit 2
}

$live = Read-JsonFile $LiveCoveragePath
$exercise = Read-JsonFile $ExerciseReportPath

$actions = @()
foreach ($page in @($catalog.pages)) {
  foreach ($action in @($page.actions)) {
    $actions += [pscustomobject]@{
      page_id = [string]$page.id
      page_name = [string]$page.name
      route = [string]$page.route
      id = [string]$action.id
      name = [string]$action.name
      type = [string]$action.type
      safety_mode = [string]$action.safety_mode
      safety = [string]$action.safety
      source_map = [string]$action.source_map
      locator_strategy = [string]$action.locator_strategy
      context = [string]$action.context
      purpose = [string]$action.purpose
      function_source = [string]$action.function_source
      locator = $action.locator
    }
  }
}

$manualReviewActions = @()
$mapOnlyActions = @()
$emptyLocatorActions = @()
if ($catalog.audit) {
  $manualReviewActions = @($catalog.audit.manual_review_actions)
  $mapOnlyActions = @($catalog.audit.map_only_actions)
  $emptyLocatorActions = @($catalog.audit.empty_locator_actions)
}

$noPurpose = @($actions | Where-Object { !$_.purpose })
$noFunctionSource = @($actions | Where-Object { !$_.function_source })
$noContext = @($actions | Where-Object { !$_.context })
$rowContextActions = @($actions | Where-Object { $_.locator_strategy -like "row_context_required*" -or $_.type -in @("row_action", "row_navigation", "row_operation") })
$tableColumnActions = @($actions | Where-Object { $_.type -eq "table_column" -or $_.locator_strategy -eq "read_table_column_header" })
$writeActions = @($actions | Where-Object { $_.safety_mode -eq "confirmation_required_write" })
$exportActions = @($actions | Where-Object { $_.safety_mode -eq "confirmation_required_export" })
$safeActions = @($actions | Where-Object { $_.safety_mode -eq "safe_execute_allowed" })
$cssSelectorActions = @($actions | Where-Object { $_.locator_strategy -eq "click_css_selector" })

$liveTotals = [ordered]@{
  loaded = [bool]$live
  pages_selected = $null
  pages_captured = $null
  pages_noaccess = $null
  observed_controls = $null
  matched_controls = $null
  missing_controls = $null
  pages_with_missing_controls = $null
}
if ($live -and $live.totals) {
  foreach ($name in @("pages_selected", "pages_captured", "pages_noaccess", "observed_controls", "matched_controls", "missing_controls", "pages_with_missing_controls")) {
    $liveTotals[$name] = Get-PropertyValue $live.totals $name
  }
}

$exerciseTotals = [ordered]@{
  loaded = [bool]$exercise
  executable_actions = $null
  attempted_actions = $null
  verified_actions = $null
  failed_actions = $null
  not_attempted_actions = $null
}
if ($exercise -and $exercise.totals) {
  foreach ($name in @("executable_actions", "attempted_actions", "verified_actions", "failed_actions", "not_attempted_actions")) {
    $exerciseTotals[$name] = Get-PropertyValue $exercise.totals $name
  }
}

$remainingBoundaries = @()
if (($liveTotals.pages_noaccess -as [int]) -gt 0) {
  $remainingBoundaries += [ordered]@{
    kind = "noaccess_live_pages"
    count = [int]$liveTotals.pages_noaccess
    meaning = "Visible controls cannot be fully proven for these route pages under the current account/session."
  }
}
if ($writeActions.Count -gt 0) {
  $remainingBoundaries += [ordered]@{
    kind = "confirmation_required_write"
    count = $writeActions.Count
    meaning = "Write/delete/save/submit actions are remembered but must not execute without explicit confirmation."
  }
}
if ($exportActions.Count -gt 0) {
  $remainingBoundaries += [ordered]@{
    kind = "confirmation_required_export"
    count = $exportActions.Count
    meaning = "Export/download actions are remembered but require explicit confirmation before execution."
  }
}
if ($rowContextActions.Count -gt 0) {
  $remainingBoundaries += [ordered]@{
    kind = "row_context_required"
    count = $rowContextActions.Count
    meaning = "Row-level actions need resolved row context: explicit RowIndex/RowText or row intent inferred from phrases such as first row / contains text; the invoker refuses to blindly click a row."
  }
}
if ($tableColumnActions.Count -gt 0) {
  $remainingBoundaries += [ordered]@{
    kind = "read_only_table_memory"
    count = $tableColumnActions.Count
    meaning = "Table columns/metrics are remembered for reading/planning and are not clickable actions."
  }
}

$qualityOk = (
  $noPurpose.Count -eq 0 -and
  $noFunctionSource.Count -eq 0 -and
  $noContext.Count -eq 0 -and
  (Get-ObjectCount $manualReviewActions) -eq 0 -and
  (Get-ObjectCount $mapOnlyActions) -eq 0 -and
  (Get-ObjectCount $emptyLocatorActions) -eq 0
)
$liveOk = ($live -and ([int](Get-PropertyValue $live.totals "missing_controls" 1)) -eq 0 -and ([int](Get-PropertyValue $live.totals "pages_with_missing_controls" 1)) -eq 0)
$exerciseOk = ($exercise -and ([int](Get-PropertyValue $exercise.totals "failed_actions" 1)) -eq 0 -and ([int](Get-PropertyValue $exercise.totals "not_attempted_actions" 1)) -eq 0)

$payload = [ordered]@{
  ok = [bool]($qualityOk -and $liveOk -and $exerciseOk)
  version = (Get-Date).ToString("yyyy-MM-dd")
  generated_at = (Get-Date).ToUniversalTime().ToString("o")
  catalog_path = $CatalogPath
  live_coverage_path = $LiveCoveragePath
  exercise_report_path = $ExerciseReportPath
  totals = [ordered]@{
    pages = [int]$catalog.totals.pages
    actions = [int]$catalog.totals.actions
    safe_execute_allowed = $safeActions.Count
    confirmation_required_write = $writeActions.Count
    confirmation_required_export = $exportActions.Count
    table_column_memory = $tableColumnActions.Count
    row_context_required = $rowContextActions.Count
    row_context_executable_with_explicit_context = $rowContextActions.Count
    row_context_executable_with_resolved_context = $rowContextActions.Count
    css_selector_actions = $cssSelectorActions.Count
  }
  quality = [ordered]@{
    ok = [bool]$qualityOk
    no_purpose = $noPurpose.Count
    no_function_source = $noFunctionSource.Count
    no_context = $noContext.Count
    manual_review_actions = Get-ObjectCount $manualReviewActions
    map_only_actions = Get-ObjectCount $mapOnlyActions
    empty_locator_actions = Get-ObjectCount $emptyLocatorActions
  }
  live_coverage = $liveTotals
  safe_action_exercise = $exerciseTotals
  remaining_boundaries = @($remainingBoundaries)
  next_action = if ($qualityOk -and $liveOk -and $exerciseOk) {
    "rpa_memory_ready_for_accessible_visible_safe_controls"
  } elseif (!$qualityOk) {
    "fix_catalog_quality_gaps"
  } elseif (!$liveOk) {
    "rerun_live_button_coverage_or_learn_missing_controls"
  } else {
    "rerun_safe_action_exercise"
  }
}

$jsonDir = Split-Path -Parent $OutputJsonPath
$mdDir = Split-Path -Parent $OutputMarkdownPath
if ($jsonDir) { New-Item -ItemType Directory -Force -Path $jsonDir | Out-Null }
if ($mdDir) { New-Item -ItemType Directory -Force -Path $mdDir | Out-Null }
$payload | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $OutputJsonPath -Encoding UTF8

$lines = @()
$lines += "# Xinjian RPA Readiness"
$lines += ""
$lines += "- Catalog: $($payload.totals.pages) pages / $($payload.totals.actions) actions"
$lines += "- Quality gaps: purpose $($payload.quality.no_purpose), function_source $($payload.quality.no_function_source), context $($payload.quality.no_context), manual/map/empty $($payload.quality.manual_review_actions)/$($payload.quality.map_only_actions)/$($payload.quality.empty_locator_actions)"
$lines += "- Live controls: observed $($payload.live_coverage.observed_controls), matched $($payload.live_coverage.matched_controls), missing $($payload.live_coverage.missing_controls), no-access pages $($payload.live_coverage.pages_noaccess)"
$lines += "- Safe action exercise: executable $($payload.safe_action_exercise.executable_actions), verified $($payload.safe_action_exercise.verified_actions), failed $($payload.safe_action_exercise.failed_actions), not attempted $($payload.safe_action_exercise.not_attempted_actions)"
$lines += "- Row-context execution: $($payload.totals.row_context_executable_with_resolved_context) row-level actions can be planned with explicit or inferred row context; none are blindly clicked by default."
$lines += "- Next action: $($payload.next_action)"
$lines += ""
$lines += "## Remaining Boundaries"
$lines += ""
if ($remainingBoundaries.Count -eq 0) {
  $lines += "- None."
} else {
  foreach ($item in $remainingBoundaries) {
    $lines += ("- {0}: {1}. {2}" -f $item.kind, $item.count, $item.meaning)
  }
}
$lines += ""
$lines += "This report is generated from public sanitized catalog, live coverage, and safe exercise evidence. It does not store cookies, tokens, input values, table row data, or private business values."
$lines | Set-Content -LiteralPath $OutputMarkdownPath -Encoding UTF8

if ($Json) {
  $payload | ConvertTo-Json -Depth 12
} else {
  Write-Host "XINJIAN_RPA_READINESS_OK=$($payload.ok)"
  Write-Host "JSON: $OutputJsonPath"
  Write-Host "Markdown: $OutputMarkdownPath"
}

if (!$payload.ok) { exit 1 }
exit 0
