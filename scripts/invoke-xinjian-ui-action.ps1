[CmdletBinding(PositionalBinding = $false)]
param(
  [Parameter(Mandatory = $true)]
  [string]$Intent,
  [string]$Url = "",
  [int]$Port = 9342,
  [switch]$Execute,
  [switch]$AllowWrite,
  [switch]$AllowExport,
  [int]$CandidateIndex = 0,
  [switch]$Json
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path

function ConvertFrom-JsonText($Lines) {
  $text = (($Lines | Out-String).Trim())
  if (!$text) { return $null }
  try { return $text | ConvertFrom-Json } catch { return $null }
}

function Get-SafetyMode([string]$Safety) {
  if ($Safety -like "confirmation_required_export*") { return "confirmation_required_export" }
  if ($Safety -like "confirmation_required*") { return "confirmation_required_write" }
  if ($Safety -in @("read_filter", "navigation", "view_setting", "account_menu", "opens_dialog_no_submit")) { return "safe_execute_allowed" }
  return "dry_run_only_unknown_safety"
}

function Join-Codepoints([int[]]$Codes) {
  return -join ($Codes | ForEach-Object { [char]$_ })
}

function Get-LocatorStrategy($Action) {
  $locator = $Action.locator
  if ($locator) {
    if ($locator.trigger_selector -and $locator.item_text) { return "click_trigger_selector_then_overlay_item_text" }
    if ($locator.trigger_selector -and $locator.button_text) { return "click_trigger_selector_then_dialog_button_text" }
    if ($locator.trigger_selector) { return "click_trigger_selector" }
    if ($locator.table_selector -and $locator.row_action_text) { return "click_first_matching_row_action_in_table" }
    if ($locator.href) { return "navigate_href" }
    if ($locator.dom_text) { return "click_visible_dom_text" }
    if ($locator.dom_placeholder) { return "input_or_filter_placeholder" }
    if ($locator.tab_texts -and $locator.dom_placeholders) { return "click_quick_tab_text_or_placeholder_list" }
    if ($locator.tab_texts) { return "click_visible_tab_text_from_list" }
    if ($locator.dom_placeholders) { return "input_or_filter_placeholder_list" }
    if ($locator.table_column) { return "row_context_required_column_header" }
    if ($locator.uia_name) { return "map_only_uia_locator" }
  }
  $type = [string]$Action.type
  $name = [string]$Action.name
  $genericTabNames = @(
    (Join-Codepoints @(0x5E73, 0x53F0, 0x6807, 0x7B7E))
  )
  $genericRowNames = @(
    (Join-Codepoints @(0x884C, 0x5206, 0x6790)),
    (Join-Codepoints @(0x64CD, 0x4F5C))
  )
  if ($name -and ($type -in @("tab", "status_tab")) -and ($name -notin $genericTabNames)) { return "click_visible_action_text" }
  if ($name -and $type -eq "row_navigation" -and ($name -notin $genericRowNames)) { return "click_visible_action_text" }
  if ($name -and $type -eq "date_filter") { return "click_visible_filter_label_or_text" }
  if (!$locator) { return "no_locator" }
  return "best_effort_locator"
}

$queryRaw = @(& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "query-xinjian-ui-action.ps1") -Intent $Intent -Url $Url -Json 2>&1)
$queryExit = $LASTEXITCODE
$query = ConvertFrom-JsonText $queryRaw
if (!$query) {
  $payload = [ordered]@{
    ok = $false
    error = "query_output_parse_failed"
    exit_code = $queryExit
    raw_output = ($queryRaw | Out-String).Trim()
  }
  if ($Json) { $payload | ConvertTo-Json -Depth 8 } else { Write-Host $payload.error }
  exit 2
}

$matches = @($query.matches)
if (!$query.ok -or $matches.Count -eq 0) {
  $payload = [ordered]@{
    ok = $false
    mode = "no_match"
    intent = $Intent
    url = $Url
    query = $query
    next_action = "capture_current_page_then_update_xinjian_ui_map"
  }
  if ($Json) { $payload | ConvertTo-Json -Depth 16 } else { Write-Host "No mapped Xinjian action matched." }
  exit 1
}

if ($CandidateIndex -lt 0 -or $CandidateIndex -ge $matches.Count) {
  $CandidateIndex = 0
}
$match = $matches[$CandidateIndex]
$action = $match.action
$safety = [string]$action.safety
$safetyMode = Get-SafetyMode $safety
$locatorStrategy = Get-LocatorStrategy $action
$requiresExport = ($safetyMode -eq "confirmation_required_export")
$requiresWrite = ($safetyMode -eq "confirmation_required_write")
$unknownSafety = ($safetyMode -eq "dry_run_only_unknown_safety")
$requiresRowContext = ($locatorStrategy -like "row_context_required*")
$canExecute = !$unknownSafety -and !$requiresRowContext -and (!$requiresExport -or $AllowExport -or $AllowWrite) -and (!$requiresWrite -or $AllowWrite)

$plan = [ordered]@{
  intent = $Intent
  url = $Url
  port = $Port
  candidate_index = $CandidateIndex
  page_id = $match.page_id
  page_name = $match.page_name
  score = $match.score
  rank = $match.rank
  action = $action
  safety_mode = $safetyMode
  locator_strategy = $locatorStrategy
  execute_requested = [bool]$Execute
  can_execute = [bool]$canExecute
  safety_note = if ($requiresRowContext) {
    "Row-level action needs an explicit row context or captured row button metadata. Dry-run only; refusing to blindly click the first row."
  } elseif ($requiresWrite) {
    "Write/delete/save/submit-like action. Dry-run by default; pass -Execute -AllowWrite only after explicit user confirmation."
  } elseif ($requiresExport) {
    "Export/download action. Dry-run by default; pass -Execute -AllowExport only after explicit user confirmation."
  } elseif ($unknownSafety) {
    "Unknown safety. Dry-run only until this action is manually classified."
  } else {
    "Safe non-write action can be executed with -Execute."
  }
}

if (!$Execute) {
  $payload = [ordered]@{
    ok = $true
    mode = "dry_run"
    plan = $plan
    query_versions = [ordered]@{
      map = $query.map_version
      auto_map = $query.auto_map_version
      overlay_map = $query.overlay_map_version
      dialog_map = $query.dialog_map_version
      row_action_map = $query.row_action_map_version
    }
    alternatives = @($matches | Select-Object -Skip 1 -First 4)
  }
  if ($Json) {
    $payload | ConvertTo-Json -Depth 20
  } else {
    Write-Host ("DRY-RUN {0} / {1} -> {2} ({3})" -f $match.page_name, $action.name, $action.purpose, $safetyMode)
  }
  exit 0
}

if (!$canExecute) {
  $payload = [ordered]@{
    ok = $false
    mode = "blocked_by_safety"
    plan = $plan
    next_action = if ($requiresRowContext) { "provide_row_context_or_capture_row_action_buttons" } elseif ($requiresWrite) { "rerun_with_execute_allow_write_after_explicit_confirmation" } elseif ($requiresExport) { "rerun_with_execute_allow_export_after_explicit_confirmation" } else { "manual_review_action_safety" }
  }
  if ($Json) {
    $payload | ConvertTo-Json -Depth 20
  } else {
    Write-Host ("Blocked by safety: {0}" -f $plan.safety_note)
  }
  exit 3
}

$node = Get-Command node -ErrorAction SilentlyContinue
if (!$node) {
  $payload = [ordered]@{
    ok = $false
    error = "node_missing"
    message = "Node.js is required for CDP action execution."
    plan = $plan
  }
  if ($Json) { $payload | ConvertTo-Json -Depth 16 } else { Write-Host $payload.message }
  exit 2
}

$helper = Join-Path $PSScriptRoot "invoke-xinjian-ui-action-cdp.mjs"
if (!(Test-Path -LiteralPath $helper)) {
  $payload = [ordered]@{
    ok = $false
    error = "invoke_helper_missing"
    path = $helper
    plan = $plan
  }
  if ($Json) { $payload | ConvertTo-Json -Depth 16 } else { Write-Host "Missing helper: $helper" }
  exit 2
}

$stateDir = Join-Path $root ".ziniao-ops\xinjian-action-runner"
New-Item -ItemType Directory -Force -Path $stateDir | Out-Null
$actionPath = Join-Path $stateDir ("action-{0}.json" -f ([guid]::NewGuid().ToString("N")))
$actionForRun = $action | ConvertTo-Json -Depth 14 | ConvertFrom-Json
$actionForRun | Add-Member -NotePropertyName "runtime_intent" -NotePropertyValue $Intent -Force
$actionForRun | ConvertTo-Json -Depth 14 | Set-Content -LiteralPath $actionPath -Encoding UTF8

$argsList = @($helper, "--port", [string]$Port, "--match-url", $Url, "--action-file", $actionPath)
if ($AllowWrite) { $argsList += "--allow-write" }
if ($AllowExport) { $argsList += "--allow-export" }
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
  $raw = @(& node @argsList 2>&1)
  $code = $LASTEXITCODE
} finally {
  $ErrorActionPreference = $previousErrorActionPreference
}
Remove-Item -LiteralPath $actionPath -ErrorAction SilentlyContinue
$result = ConvertFrom-JsonText $raw
if (!$result) {
  $result = [pscustomobject]@{
    ok = $false
    error = "invoke_output_parse_failed"
    exit_code = $code
    raw_output = ($raw | Out-String).Trim()
  }
}

$payload = [ordered]@{
  ok = [bool]$result.ok
  mode = "executed"
  plan = $plan
  result = $result
}
if ($Json) {
  $payload | ConvertTo-Json -Depth 20
} else {
  if ($result.ok) {
    Write-Host ("Executed Xinjian action: {0}" -f $action.name)
  } else {
    Write-Host ("Xinjian action execution failed: {0}" -f $result.error)
  }
}
exit $code
