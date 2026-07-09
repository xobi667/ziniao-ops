param(
  [int]$Port = 9342,
  [string]$Origin = "https://erp.xinjianerp.com",
  [string]$PageId = "",
  [string[]]$ActionId = @(),
  [string]$RouteRegex = ".",
  [string[]]$ActionType = @(),
  [int]$MaxActions = 25,
  [int]$WaitMs = 8000,
  [string]$StatePath = "",
  [switch]$RetryAttempted,
  [switch]$RetryFailed,
  [switch]$IncludeAccountMenu,
  [switch]$IncludeRowActions,
  [switch]$DryRun,
  [switch]$WritePublicReport,
  [switch]$Json
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$catalogPath = Join-Path $root "references\xinjian-ui-action-catalog.json"
$helperPath = Join-Path $PSScriptRoot "invoke-xinjian-ui-action-cdp.mjs"
if (!$StatePath) {
  $StatePath = Join-Path $root ".ziniao-ops\xinjian-safe-action-exercise-state.json"
}
$stateDir = Split-Path -Parent $StatePath
New-Item -ItemType Directory -Force -Path $stateDir | Out-Null

$publicReportJson = Join-Path $root "references\xinjian-ui-action-exercise-report.json"
$publicReportMd = Join-Path $root "references\xinjian-ui-action-exercise-report.md"

function ConvertFrom-JsonText($Lines) {
  $text = (($Lines | Out-String).Trim())
  if (!$text) { return $null }
  try { return $text | ConvertFrom-Json } catch {
    $starts = @($text.IndexOf("{"), $text.IndexOf("[")) | Where-Object { $_ -ge 0 } | Sort-Object
    if ($starts.Count -gt 0) {
      try { return $text.Substring([int]$starts[0]) | ConvertFrom-Json } catch { return $null }
    }
    return $null
  }
}

function Test-CdpPort([int]$CdpPort) {
  try {
    Invoke-RestMethod -Uri "http://127.0.0.1:$CdpPort/json/version" -TimeoutSec 3 | Out-Null
    return $true
  } catch {
    return $false
  }
}

function Open-CdpUrl([int]$CdpPort, [string]$TargetUrl) {
  $encoded = [uri]::EscapeDataString($TargetUrl)
  foreach ($endpoint in @(
      "http://127.0.0.1:$CdpPort/json/new?$encoded",
      "http://127.0.0.1:$CdpPort/json/new?url=$encoded"
  )) {
    foreach ($method in @("PUT", "GET")) {
      try {
        return Invoke-RestMethod -Method $method -Uri $endpoint -TimeoutSec 8
      } catch {
      }
    }
  }
  return $null
}

function Close-CdpPage([int]$CdpPort, [string]$TargetId) {
  if (!$TargetId) { return }
  try {
    Invoke-RestMethod -Uri "http://127.0.0.1:$CdpPort/json/close/$TargetId" -TimeoutSec 3 | Out-Null
  } catch {
  }
}

function Get-State {
  if (!(Test-Path -LiteralPath $StatePath)) {
    return [pscustomobject]@{
      version = "2026-07-09"
      source = "xinjian_safe_action_exercise"
      attempts = @()
    }
  }
  try {
    $state = Get-Content -LiteralPath $StatePath -Raw -Encoding UTF8 | ConvertFrom-Json
    if (!$state.PSObject.Properties.Match("attempts").Count) {
      $state | Add-Member -NotePropertyName attempts -NotePropertyValue @()
    }
    return $state
  } catch {
    return [pscustomobject]@{
      version = "2026-07-09"
      source = "xinjian_safe_action_exercise"
      attempts = @()
    }
  }
}

function Save-State($State) {
  $State | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $StatePath -Encoding UTF8
}

function Get-LatestAttemptMap($Attempts) {
  $map = @{}
  foreach ($attempt in @($Attempts)) {
    if (!$attempt.action_id) { continue }
    $map[[string]$attempt.action_id] = $attempt
  }
  return $map
}

function Get-RouteUrl([string]$Route) {
  if (!$Route) { return "" }
  if ($Route -match "^https?://") { return $Route }
  return ($Origin.TrimEnd("/") + "/" + $Route.TrimStart("/"))
}

function Test-ExecutableAction($Action) {
  if ([string]$Action.safety_mode -ne "safe_execute_allowed") { return $false }
  if ([string]$Action.locator_strategy -eq "read_table_column_header") { return $false }
  if ([string]$Action.locator_strategy -like "row_context_required*") { return $false }
  if ([bool]$Action.confirmation_required) { return $false }
  if (!$IncludeRowActions -and [string]$Action.type -eq "row_action") { return $false }
  if (!$IncludeRowActions -and [string]$Action.type -eq "row_navigation") { return $false }
  if (!$IncludeAccountMenu -and ([string]$Action.safety -eq "account_menu" -or [string]$Action.name -eq "用户菜单")) { return $false }

  $defaultTypes = @(
    "button",
    "button_menu",
    "date_filter",
    "dialog_button",
    "dialog_opener",
    "filter_dropdown",
    "filter_input",
    "form_input",
    "module_switch",
    "navigation",
    "overlay_item",
    "overlay_trigger",
    "status_tab",
    "tab"
  )
  if ($IncludeRowActions) { $defaultTypes += @("row_action", "row_navigation") }

  $types = if ($ActionType.Count -gt 0) { @($ActionType) } else { $defaultTypes }
  return ([string]$Action.type) -in $types
}

function New-ExerciseCandidate($Page, $Action) {
  $url = Get-RouteUrl ([string]$Page.route)
  [pscustomobject]@{
    page_id = [string]$Page.id
    page_name = [string]$Page.name
    route = [string]$Page.route
    url = $url
    action = $Action
  }
}

function Get-Candidates($Catalog, $AttemptMap) {
  $items = @()
  foreach ($page in @($Catalog.pages)) {
    $route = [string]$page.route
    if (!$route) { continue }
    if ($PageId -and [string]$page.id -ne $PageId) { continue }
    if ($RouteRegex -and $route -notmatch $RouteRegex) { continue }
    foreach ($action in @($page.actions)) {
      if ($ActionId.Count -gt 0 -and ([string]$action.id) -notin $ActionId) { continue }
      if (!(Test-ExecutableAction $action)) { continue }
      $previousAttempt = $AttemptMap[[string]$action.id]
      if ($RetryFailed) {
        if (!$previousAttempt -or [string]$previousAttempt.status -ne "failed") { continue }
      } elseif (!$RetryAttempted -and $previousAttempt) {
        continue
      }
      $items += New-ExerciseCandidate -Page $page -Action $action
    }
  }
  if ($MaxActions -gt 0) {
    $items = @($items | Select-Object -First $MaxActions)
  }
  return $items
}

function Invoke-SafeAction($Candidate) {
  $openedPage = $null
  $actionPath = ""
  try {
    $openedPage = Open-CdpUrl -CdpPort $Port -TargetUrl $Candidate.url
    if (!$openedPage -or !$openedPage.id) {
      return [pscustomobject]@{
        ok = $false
        error = "open_cdp_url_failed"
        exit_code = $null
      }
    }
    Start-Sleep -Milliseconds $WaitMs

    $actionPath = Join-Path $stateDir ("exercise-action-{0}.json" -f ([guid]::NewGuid().ToString("N")))
    $Candidate.action | ConvertTo-Json -Depth 14 | Set-Content -LiteralPath $actionPath -Encoding UTF8

    $raw = @(& node $helperPath --port ([string]$Port) --match-url $Candidate.url --action-file $actionPath 2>&1)
    $code = $LASTEXITCODE
    $result = ConvertFrom-JsonText $raw
    if (!$result) {
      $result = [pscustomobject]@{
        ok = $false
        error = "invoke_output_parse_failed"
        exit_code = $code
        raw_output = ($raw | Out-String).Trim()
      }
    }
    if (!$result.PSObject.Properties.Match("exit_code").Count) {
      $result | Add-Member -NotePropertyName exit_code -NotePropertyValue $code
    }
    return $result
  } finally {
    if ($actionPath) { Remove-Item -LiteralPath $actionPath -ErrorAction SilentlyContinue }
    if ($openedPage -and $openedPage.id) {
      Close-CdpPage -CdpPort $Port -TargetId ([string]$openedPage.id)
    }
  }
}

function Get-CountMap($Items) {
  $map = [ordered]@{}
  foreach ($group in @($Items | Group-Object)) {
    $map[[string]$group.Name] = [int]$group.Count
  }
  return $map
}

function Write-PublicExerciseReport($Catalog, $State, $SelectedCount) {
  $latest = Get-LatestAttemptMap @($State.attempts)
  $allExecutable = @()
  foreach ($page in @($Catalog.pages)) {
    if (![string]$page.route) { continue }
    foreach ($action in @($page.actions)) {
      if (!(Test-ExecutableAction $action)) { continue }
      $allExecutable += [pscustomobject]@{
        page_id = [string]$page.id
        page_name = [string]$page.name
        route = [string]$page.route
        action_id = [string]$action.id
        action_name = [string]$action.name
        action_type = [string]$action.type
        safety = [string]$action.safety
        locator_strategy = [string]$action.locator_strategy
      }
    }
  }

  $attemptRows = @()
  foreach ($item in $allExecutable) {
    $attempt = $latest[[string]$item.action_id]
    $attemptRows += [pscustomobject]@{
      page_id = $item.page_id
      route = $item.route
      action_id = $item.action_id
      action_name = $item.action_name
      action_type = $item.action_type
      locator_strategy = $item.locator_strategy
      status = if ($attempt) { [string]$attempt.status } else { "not_attempted" }
      error = if ($attempt) { [string]$attempt.error } else { "" }
      verified_at = if ($attempt) { [string]$attempt.verified_at } else { "" }
    }
  }
  $attempted = @($attemptRows | Where-Object { $_.status -ne "not_attempted" })
  $verified = @($attemptRows | Where-Object { $_.status -eq "verified" })
  $failed = @($attemptRows | Where-Object { $_.status -eq "failed" })

  $payload = [ordered]@{
    version = "2026-07-09"
    system = "xinjian_erp"
    source = "generated_from_local_safe_action_exercise_state"
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    policy = [ordered]@{
      note = "This report stores only public action ids, routes, action names, action types, locator strategies, and execution status. It does not store cookies, tokens, input values, table row data, or private business values."
      executed_scope = "route-scoped safe_execute_allowed CDP actions except read-only table columns, account menu by default, confirmation-required actions, row actions unless explicitly included, and no-route UIA global actions."
    }
    totals = [ordered]@{
      executable_actions = @($allExecutable).Count
      attempted_actions = @($attempted).Count
      verified_actions = @($verified).Count
      failed_actions = @($failed).Count
      not_attempted_actions = (@($allExecutable).Count - @($attempted).Count)
      selected_in_last_run = $SelectedCount
      type_counts = Get-CountMap (@($allExecutable) | ForEach-Object { $_.action_type })
      status_counts = Get-CountMap (@($attemptRows) | ForEach-Object { $_.status })
    }
    recent_failures = @($failed | Sort-Object verified_at -Descending | Select-Object -First 20)
    actions = @($attemptRows)
  }
  $payload | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $publicReportJson -Encoding UTF8

  $lines = @()
  $lines += "# Xinjian Safe Action Exercise Report"
  $lines += ""
  $lines += ("Generated at: {0}" -f $payload.generated_at)
  $lines += ""
  $lines += "This report contains sanitized execution status for safe non-write Xinjian UI actions only. It excludes cookies, tokens, input values, table row data, and private business values."
  $lines += ""
  $lines += "## Totals"
  $lines += ""
  $lines += ("- Executable safe actions: {0}" -f $payload.totals.executable_actions)
  $lines += ("- Attempted actions: {0}" -f $payload.totals.attempted_actions)
  $lines += ("- Verified actions: {0}" -f $payload.totals.verified_actions)
  $lines += ("- Failed actions: {0}" -f $payload.totals.failed_actions)
  $lines += ("- Not attempted actions: {0}" -f $payload.totals.not_attempted_actions)
  $lines += ""
  $lines += "## Status By Type"
  $lines += ""
  $lines += "| Type | Total | Verified | Failed | Not Attempted |"
  $lines += "| --- | ---: | ---: | ---: | ---: |"
  foreach ($type in @($allExecutable | Select-Object -ExpandProperty action_type -Unique | Sort-Object)) {
    $rows = @($attemptRows | Where-Object { $_.action_type -eq $type })
    $lines += ("| {0} | {1} | {2} | {3} | {4} |" -f $type, $rows.Count, @($rows | Where-Object { $_.status -eq "verified" }).Count, @($rows | Where-Object { $_.status -eq "failed" }).Count, @($rows | Where-Object { $_.status -eq "not_attempted" }).Count)
  }
  if ($failed.Count -gt 0) {
    $lines += ""
    $lines += "## Recent Failures"
    $lines += ""
    $lines += "| Route | Action | Type | Error |"
    $lines += "| --- | --- | --- | --- |"
    foreach ($failure in @($payload.recent_failures)) {
      $lines += ("| {0} | {1} | {2} | {3} |" -f $failure.route, $failure.action_name, $failure.action_type, $failure.error)
    }
  }
  $lines -join [Environment]::NewLine | Set-Content -LiteralPath $publicReportMd -Encoding UTF8
  return $payload
}

if (!(Test-Path -LiteralPath $catalogPath)) {
  $payload = [ordered]@{ ok = $false; error = "catalog_missing"; path = $catalogPath }
  if ($Json) { $payload | ConvertTo-Json -Depth 8 } else { Write-Host "Missing catalog: $catalogPath" }
  exit 2
}
if (!(Test-Path -LiteralPath $helperPath)) {
  $payload = [ordered]@{ ok = $false; error = "invoke_helper_missing"; path = $helperPath }
  if ($Json) { $payload | ConvertTo-Json -Depth 8 } else { Write-Host "Missing helper: $helperPath" }
  exit 2
}
if (!(Get-Command node -ErrorAction SilentlyContinue)) {
  $payload = [ordered]@{ ok = $false; error = "node_missing"; message = "Node.js is required for CDP action exercise." }
  if ($Json) { $payload | ConvertTo-Json -Depth 8 } else { Write-Host $payload.message }
  exit 2
}
if (!$DryRun -and !(Test-CdpPort -CdpPort $Port)) {
  $payload = [ordered]@{ ok = $false; error = "cdp_port_not_reachable"; port = $Port }
  if ($Json) { $payload | ConvertTo-Json -Depth 8 } else { Write-Host "CDP port not reachable: $Port" }
  exit 2
}

$catalog = Get-Content -LiteralPath $catalogPath -Raw -Encoding UTF8 | ConvertFrom-Json
$state = Get-State
$attemptMap = Get-LatestAttemptMap @($state.attempts)
$candidates = @(Get-Candidates -Catalog $catalog -AttemptMap $attemptMap)

if ($DryRun) {
  $report = if ($WritePublicReport) { Write-PublicExerciseReport -Catalog $catalog -State $state -SelectedCount $candidates.Count } else { $null }
  $payload = [ordered]@{
    ok = $true
    mode = "dry_run"
    port = $Port
    state_path = [System.IO.Path]::GetFullPath($StatePath)
    selected_count = $candidates.Count
    selected = @($candidates | ForEach-Object {
      [ordered]@{
        page_id = $_.page_id
        route = $_.route
        action_id = $_.action.id
        action_name = $_.action.name
        action_type = $_.action.type
        locator_strategy = $_.action.locator_strategy
      }
    })
    public_report = if ($report) { [ordered]@{ json = $publicReportJson; md = $publicReportMd; totals = $report.totals } } else { $null }
  }
  if ($Json) { $payload | ConvertTo-Json -Depth 12 } else { Write-Host ("Would exercise {0} safe Xinjian actions." -f $candidates.Count) }
  exit 0
}

$results = @()
foreach ($candidate in $candidates) {
  $result = Invoke-SafeAction -Candidate $candidate
  $status = if ($result.ok) { "verified" } else { "failed" }
  $attempt = [ordered]@{
    action_id = [string]$candidate.action.id
    action_name = [string]$candidate.action.name
    action_type = [string]$candidate.action.type
    page_id = [string]$candidate.page_id
    page_name = [string]$candidate.page_name
    route = [string]$candidate.route
    safety = [string]$candidate.action.safety
    locator_strategy = [string]$candidate.action.locator_strategy
    status = $status
    error = if ($result.error) { [string]$result.error } else { "" }
    execution_backend = "cdp"
    port = $Port
    verified_at = (Get-Date).ToUniversalTime().ToString("o")
  }
  $state.attempts += [pscustomobject]$attempt
  Save-State $state
  $results += [pscustomobject]@{
    action_id = $attempt.action_id
    action_name = $attempt.action_name
    action_type = $attempt.action_type
    page_id = $attempt.page_id
    route = $attempt.route
    ok = [bool]$result.ok
    error = $attempt.error
  }
}

$reportPayload = if ($WritePublicReport) { Write-PublicExerciseReport -Catalog $catalog -State $state -SelectedCount $candidates.Count } else { $null }
$failed = @($results | Where-Object { !$_.ok })
$payload = [ordered]@{
  ok = ($failed.Count -eq 0)
  mode = "executed"
  port = $Port
  state_path = [System.IO.Path]::GetFullPath($StatePath)
  selected_count = $candidates.Count
  verified_count = @($results | Where-Object { $_.ok }).Count
  failed_count = $failed.Count
  results = @($results)
  public_report = if ($reportPayload) { [ordered]@{ json = $publicReportJson; md = $publicReportMd; totals = $reportPayload.totals } } else { $null }
  next_action = if ($candidates.Count -eq 0) { "no_unattempted_safe_actions_for_current_filter" } elseif ($failed.Count -gt 0) { "review_failed_safe_action_locators_then_retry" } else { "continue_exercising_remaining_safe_actions" }
}
if ($Json) {
  $payload | ConvertTo-Json -Depth 14
} else {
  Write-Host ("Exercised {0} safe Xinjian actions: {1} verified, {2} failed." -f $candidates.Count, $payload.verified_count, $payload.failed_count)
}
if ($failed.Count -gt 0) { exit 4 }
exit 0
