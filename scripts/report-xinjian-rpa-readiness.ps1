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

function Get-RouteKey([string]$Value) {
  if (!$Value) { return "" }
  $text = [string]$Value
  if ($text -match "^[A-Za-z][A-Za-z0-9+.-]*://") {
    try { $text = ([uri]$text).AbsolutePath } catch {}
  }
  if (!$text.StartsWith("/")) { $text = "/" + $text }
  $text = $text -replace "/+", "/"
  if ($text.Length -gt 1) { $text = $text.TrimEnd("/") }
  return $text
}

function Test-RestrictedTerminalPage($Page) {
  $route = (Get-RouteKey ([string](Get-PropertyValue $Page "route" ""))).ToLowerInvariant()
  $capturedPath = (Get-RouteKey ([string](Get-PropertyValue $Page "captured_path" ""))).ToLowerInvariant()
  $pageId = [string](Get-PropertyValue $Page "page_id" "")
  return ($route -eq "/index/noaccess" -or $capturedPath -eq "/index/noaccess" -and $pageId -eq "auto.index.noaccess")
}

function Convert-LivePageBrief($Page) {
  return [ordered]@{
    page_id = [string](Get-PropertyValue $Page "page_id" "")
    page_name = [string](Get-PropertyValue $Page "page_name" "")
    route = [string](Get-PropertyValue $Page "route" "")
    status = [string](Get-PropertyValue $Page "status" "")
    captured_path = [string](Get-PropertyValue $Page "captured_path" "")
  }
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
  pages_noaccess_raw = $null
  pages_restricted_terminal = $null
  observed_controls = $null
  matched_controls = $null
  missing_controls = $null
  pages_with_missing_controls = $null
  noaccess_pages = @()
  restricted_terminal_pages = @()
}
if ($live -and $live.totals) {
  foreach ($name in @("pages_selected", "pages_captured", "pages_noaccess", "pages_restricted_terminal", "observed_controls", "matched_controls", "missing_controls", "pages_with_missing_controls")) {
    $liveTotals[$name] = Get-PropertyValue $live.totals $name
  }
  $liveTotals.pages_noaccess_raw = Get-PropertyValue $live.totals "pages_noaccess" $null
}
if ($live -and $live.pages) {
  $restrictedTerminalPages = @($live.pages | Where-Object {
    [string](Get-PropertyValue $_ "status" "") -eq "restricted_terminal" -or
      ([string](Get-PropertyValue $_ "status" "") -eq "noaccess" -and (Test-RestrictedTerminalPage $_))
  })
  $businessNoAccessPages = @($live.pages | Where-Object {
    [string](Get-PropertyValue $_ "status" "") -eq "noaccess" -and !(Test-RestrictedTerminalPage $_)
  })
  $liveTotals.pages_noaccess = $businessNoAccessPages.Count
  $liveTotals.pages_restricted_terminal = $restrictedTerminalPages.Count
  $liveTotals.noaccess_pages = @($businessNoAccessPages | ForEach-Object { Convert-LivePageBrief $_ })
  $liveTotals.restricted_terminal_pages = @($restrictedTerminalPages | ForEach-Object { Convert-LivePageBrief $_ })
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
$nonGapBoundaries = @()
if (($liveTotals.pages_restricted_terminal -as [int]) -gt 0) {
  $nonGapBoundaries += [ordered]@{
    kind = "restricted_terminal_pages"
    count = [int]$liveTotals.pages_restricted_terminal
    meaning = "Known Xinjian access-denied terminal pages are tracked separately; they are not missing button memory."
    pages = @($liveTotals.restricted_terminal_pages)
  }
}
if ($writeActions.Count -gt 0) {
  $remainingBoundaries += [ordered]@{
    kind = "confirmation_required_write"
    count = $writeActions.Count
    meaning = "Write/delete/save/submit actions are remembered but must not execute without explicit confirmation."
    handled_by = "post_execute.write_confirmation_follow_up"
  }
}
if ($exportActions.Count -gt 0) {
  $remainingBoundaries += [ordered]@{
    kind = "confirmation_required_export"
    count = $exportActions.Count
    meaning = "Export/download actions are remembered but require explicit confirmation before execution."
    handled_by = "post_execute.export_download_follow_up"
  }
}
if ($rowContextActions.Count -gt 0) {
  $remainingBoundaries += [ordered]@{
    kind = "row_context_required"
    count = $rowContextActions.Count
    meaning = "Row-level actions need resolved row context: explicit RowIndex/RowText or row intent inferred from phrases such as first row / contains text; the invoker refuses to blindly click a row."
    handled_by = "row_context_follow_up.row_context_required_follow_up"
  }
}
if ($tableColumnActions.Count -gt 0) {
  $nonGapBoundaries += [ordered]@{
    kind = "read_only_table_memory"
    count = $tableColumnActions.Count
    meaning = "Table columns/metrics are remembered for planning and can be read from the current debuggable page through CDP without clicking; they are intentionally not treated as clickable buttons."
  }
}

$executionGuardPlans = [ordered]@{
  write_confirmation_follow_up = $writeActions.Count
  export_download_follow_up = $exportActions.Count
  row_context_required_follow_up = $rowContextActions.Count
  table_column_read_with_cdp = $tableColumnActions.Count
}
if ($writeActions.Count -gt 0) {
  $nonGapBoundaries += [ordered]@{
    kind = "write_confirmation_follow_up_plans"
    count = $writeActions.Count
    meaning = "Write/delete/save/submit buttons have machine-readable post_execute rerun and verification plans; explicit AllowWrite is still required."
  }
}
if ($exportActions.Count -gt 0) {
  $nonGapBoundaries += [ordered]@{
    kind = "export_download_follow_up_plans"
    count = $exportActions.Count
    meaning = "Export/download buttons have machine-readable post_execute rerun, wait-for-download, and download-center fallback plans; explicit AllowExport is still required."
  }
}
if ($rowContextActions.Count -gt 0) {
  $nonGapBoundaries += [ordered]@{
    kind = "row_context_follow_up_plans"
    count = $rowContextActions.Count
    meaning = "Row-level buttons have machine-readable rerun plans for RowIndex or RowText; the invoker still refuses to blindly click the first row."
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
    table_column_readable_with_cdp = $tableColumnActions.Count
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
  execution_guard_plans = $executionGuardPlans
  remaining_boundaries = @($remainingBoundaries)
  non_gap_boundaries = @($nonGapBoundaries)
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
$lines += "- Live controls: observed $($payload.live_coverage.observed_controls), matched $($payload.live_coverage.matched_controls), missing $($payload.live_coverage.missing_controls), business no-access pages $($payload.live_coverage.pages_noaccess), restricted terminal pages $($payload.live_coverage.pages_restricted_terminal)"
$lines += "- Safe action exercise: executable $($payload.safe_action_exercise.executable_actions), verified $($payload.safe_action_exercise.verified_actions), failed $($payload.safe_action_exercise.failed_actions), not attempted $($payload.safe_action_exercise.not_attempted_actions)"
$lines += "- Row-context execution: $($payload.totals.row_context_executable_with_resolved_context) row-level actions can be planned with explicit or inferred row context; none are blindly clicked by default."
$lines += "- Table-column reading: $($payload.totals.table_column_readable_with_cdp) remembered columns can be read from a debuggable current page without clicking."
$lines += "- Structured follow-up plans: write $($payload.execution_guard_plans.write_confirmation_follow_up), export $($payload.execution_guard_plans.export_download_follow_up), row-context $($payload.execution_guard_plans.row_context_required_follow_up), table-read $($payload.execution_guard_plans.table_column_read_with_cdp)."
$lines += "- Next action: $($payload.next_action)"
$lines += ""
$lines += "## Remaining Boundaries"
$lines += ""
if ($remainingBoundaries.Count -eq 0) {
  $lines += "- None."
} else {
  foreach ($item in $remainingBoundaries) {
    $suffix = if ($item.Contains("handled_by")) { " Handled by: $($item.handled_by)." } else { "" }
    $lines += ("- {0}: {1}. {2}{3}" -f $item.kind, $item.count, $item.meaning, $suffix)
  }
}
$lines += ""
if ($nonGapBoundaries.Count -gt 0) {
  $lines += "## Known Non-Gap Boundaries"
  $lines += ""
  foreach ($item in $nonGapBoundaries) {
    $lines += ("- {0}: {1}. {2}" -f $item.kind, $item.count, $item.meaning)
    if ($item.Contains("pages")) {
      foreach ($page in @($item.pages)) {
        $lines += ('  - {0} `{1}` -> `{2}`' -f $page.page_name, $page.route, $page.captured_path)
      }
    }
  }
  $lines += ""
}
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
