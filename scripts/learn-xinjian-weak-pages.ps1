[CmdletBinding(PositionalBinding = $false)]
param(
  [int[]]$Port = @(),
  [int]$MaxPages = 5,
  [int]$MinActions = 5,
  [int]$MinRiskScore = 1,
  [string[]]$IncludeGap = @(),
  [string]$StatePath = "",
  [int]$RetryAfterHours = 168,
  [switch]$IncludeRestricted,
  [switch]$RetryAttempted,
  [switch]$SkipDom,
  [switch]$SkipOverlays,
  [switch]$SkipDialogs,
  [switch]$SkipRowActions,
  [switch]$NoGenerate,
  [switch]$DryRun,
  [switch]$Json
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
if (!$StatePath) {
  $StatePath = Join-Path $root ".ziniao-ops\xinjian-weak-page-learn-state.json"
}

function ConvertFrom-JsonText($Lines) {
  $text = (($Lines | Out-String).Trim())
  if (!$text) { return $null }
  try { return $text | ConvertFrom-Json } catch {
    $objectStart = $text.IndexOf("{")
    $arrayStart = $text.IndexOf("[")
    $starts = @($objectStart, $arrayStart) | Where-Object { $_ -ge 0 } | Sort-Object
    if ($starts.Count -eq 0) { return $null }
    try { return $text.Substring([int]$starts[0]) | ConvertFrom-Json } catch { return $null }
  }
}

function Invoke-JsonScript {
  param(
    [string]$ScriptName,
    [string[]]$Arguments = @()
  )
  $scriptPath = Join-Path $PSScriptRoot $ScriptName
  if (!(Test-Path -LiteralPath $scriptPath)) {
    return [pscustomobject]@{
      ok = $false
      script = $ScriptName
      exit_code = 2
      parsed = [pscustomobject]@{ ok = $false; error = "script_missing"; path = $scriptPath }
      raw_output = ""
    }
  }
  $argsList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $scriptPath) + @($Arguments)
  $raw = @(& powershell @argsList 2>&1)
  $code = $LASTEXITCODE
  $parsed = ConvertFrom-JsonText $raw
  $parsedOk = $false
  if ($parsed -and $parsed.PSObject.Properties.Match("ok").Count -gt 0) {
    $parsedOk = [bool]$parsed.ok
  } elseif ($parsed -and $code -eq 0) {
    $parsedOk = $true
  }
  [pscustomobject]@{
    ok = ($code -eq 0 -and $parsedOk)
    script = $ScriptName
    exit_code = $code
    parsed = $parsed
    raw_output = ($raw | Out-String).Trim()
  }
}

function Get-PortArgumentList {
  param([int[]]$Ports)
  $items = @($Ports | Where-Object { $_ -gt 0 } | Sort-Object -Unique)
  $args = @()
  foreach ($item in $items) {
    $args += @("-Port", [string]$item)
  }
  return $args
}

function Get-RouteUrl([string]$Route) {
  if (!$Route) { return "" }
  if ($Route -match "^https?://") { return $Route }
  $path = [string]$Route
  if (!$path.StartsWith("/")) { $path = "/" + $path }
  return "https://erp.xinjianerp.com$path"
}

function Get-RouteKey([string]$InputUrl) {
  if (!$InputUrl) { return "" }
  try {
    $uri = [uri]$InputUrl
    $path = $uri.AbsolutePath
    if (!$path.StartsWith("/")) { $path = "/" + $path }
    if ($path.Length -gt 1) { $path = $path.TrimEnd("/") }
    return $path.ToLowerInvariant()
  } catch {
    $text = [string]$InputUrl
    if (!$text.StartsWith("/")) { $text = "/" + $text }
    if ($text.Length -gt 1) { $text = $text.TrimEnd("/") }
    return $text.ToLowerInvariant()
  }
}

function Test-LearnableRoute([string]$Route) {
  if (!$Route) { return $false }
  $key = Get-RouteKey $Route
  if (!$key) { return $false }
  if ($IncludeRestricted) { return $true }
  return $key -notmatch "(^|/)(login|401|404)(/|$)" -and $key -notmatch "noaccess"
}

function Test-IncludeGaps($Page) {
  if (@($IncludeGap).Count -eq 0) { return $true }
  $gaps = @($Page.gaps | ForEach-Object { [string]$_ })
  foreach ($gap in @($IncludeGap)) {
    if ($gaps -contains [string]$gap) { return $true }
  }
  return $false
}

function New-ReportSummary($Report) {
  if (!$Report) { return $null }
  return [ordered]@{
    pages = [int]$Report.totals.pages
    actions = [int]$Report.totals.actions
    weak_pages_count = [int]$Report.weak_pages_count
    audit_manual = [int]$Report.audit.manual_review_actions
    audit_map_only = [int]$Report.audit.map_only_actions
    audit_empty = [int]$Report.audit.empty_locator_actions
    source_coverage = $Report.source_coverage_pages
  }
}

function Read-LearnState {
  if (!(Test-Path -LiteralPath $StatePath)) {
    return [pscustomobject]@{ version = "2026-07-08"; attempts = @() }
  }
  try {
    $state = Get-Content -LiteralPath $StatePath -Raw -Encoding UTF8 | ConvertFrom-Json
    if (!$state.PSObject.Properties.Match("attempts").Count) {
      $state | Add-Member -MemberType NoteProperty -Name attempts -Value @()
    }
    return $state
  } catch {
    return [pscustomobject]@{ version = "2026-07-08"; attempts = @(); read_error = $_.Exception.Message }
  }
}

function New-AttemptMap($State) {
  $map = @{}
  foreach ($attempt in @($State.attempts)) {
    $key = [string]$attempt.route_key
    if (!$key) { $key = Get-RouteKey ([string]$attempt.route) }
    if ($key) { $map[$key] = $attempt }
  }
  return $map
}

function Test-RecentAttempt($Attempt) {
  if (!$Attempt -or $RetryAttempted -or $RetryAfterHours -le 0) { return $false }
  try {
    $last = ([datetime]::Parse([string]$Attempt.last_attempted_at)).ToUniversalTime()
    $ageHours = ((Get-Date).ToUniversalTime() - $last).TotalHours
    return $ageHours -lt $RetryAfterHours
  } catch {
    return $false
  }
}

function Write-LearnState {
  param(
    [object]$ExistingState,
    [object[]]$LearnedPages,
    [string]$GenerateSkippedReason,
    [object]$BeforeReport,
    [object]$AfterReport
  )
  $attempts = New-AttemptMap $ExistingState
  $now = (Get-Date).ToUniversalTime().ToString("o")
  $beforeActions = if ($BeforeReport) { [int]$BeforeReport.totals.actions } else { $null }
  $afterActions = if ($AfterReport) { [int]$AfterReport.totals.actions } else { $null }
  $batchDelta = if ($BeforeReport -and $AfterReport) { $afterActions - $beforeActions } else { $null }

  foreach ($item in @($LearnedPages)) {
    $routeKey = Get-RouteKey ([string]$item.route)
    if (!$routeKey) { $routeKey = Get-RouteKey ([string]$item.url) }
    if (!$routeKey) { continue }
    $attempts[$routeKey] = [pscustomobject]([ordered]@{
        route_key = $routeKey
        route = [string]$item.route
        url = [string]$item.url
        name = [string]$item.name
        risk_score = [int]$item.risk_score
        last_attempted_at = $now
        ok = [bool]$item.ok
        error = [string]$item.error
        exit_code = [int]$item.exit_code
        capture_count = @($item.captures).Count
        failed_capture_count = @($item.captures | Where-Object { !$_.ok }).Count
        generate_skipped_reason = $GenerateSkippedReason
        batch_delta_actions = $batchDelta
      })
  }

  $payload = [ordered]@{
    version = "2026-07-08"
    updated_at = $now
    retry_after_hours = $RetryAfterHours
    attempts = @($attempts.Values | Sort-Object route_key)
  }
  $dir = Split-Path -Parent $StatePath
  if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $payload | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $StatePath -Encoding UTF8
  return $payload
}

$reportResult = Invoke-JsonScript -ScriptName "report-xinjian-action-memory.ps1" -Arguments @(
  "-MinActions", [string]$MinActions,
  "-MaxWeakPages", "0",
  "-Json"
)
if (!$reportResult.ok -or !$reportResult.parsed) {
  $payload = [ordered]@{
    ok = $false
    mode = "weak_page_report_failed"
    exit_code = [int]$reportResult.exit_code
    error = if ($reportResult.parsed -and $reportResult.parsed.error) { [string]$reportResult.parsed.error } else { "report_xinjian_action_memory_failed" }
    raw_output = $reportResult.raw_output
  }
  if ($Json) { $payload | ConvertTo-Json -Depth 12 } else { Write-Host "Weak page report failed." }
  exit 1
}

$beforeReport = $reportResult.parsed
$learnState = Read-LearnState
$attemptByRoute = New-AttemptMap $learnState
$seen = @{}
$selected = @()
$skippedAttempted = @()
foreach ($page in @($beforeReport.weak_pages)) {
  if ([int]$page.risk_score -lt $MinRiskScore) { continue }
  if (!(Test-IncludeGaps $page)) { continue }
  if (!(Test-LearnableRoute ([string]$page.route))) { continue }
  $url = Get-RouteUrl ([string]$page.route)
  if (!$url) { continue }
  $key = Get-RouteKey $url
  if ($seen.ContainsKey($key)) { continue }
  $previousAttempt = $attemptByRoute[$key]
  if (Test-RecentAttempt $previousAttempt) {
    $skippedAttempted += [pscustomobject]([ordered]@{
        risk_score = [int]$page.risk_score
        module = [string]$page.module
        name = [string]$page.name
        route = [string]$page.route
        url = $url
        last_attempted_at = [string]$previousAttempt.last_attempted_at
        previous_ok = [bool]$previousAttempt.ok
        previous_error = [string]$previousAttempt.error
      })
    continue
  }
  $seen[$key] = $true
  $selected += [pscustomobject]([ordered]@{
      risk_score = [int]$page.risk_score
      module = [string]$page.module
      name = [string]$page.name
      route = [string]$page.route
      url = $url
      actions = [int]$page.actions
      gaps = @($page.gaps | ForEach-Object { [string]$_ })
    })
  if ($MaxPages -gt 0 -and $selected.Count -ge $MaxPages) { break }
}

$selectedUrls = @($selected | ForEach-Object { [string]$_.url })

if ($DryRun -or $selectedUrls.Count -eq 0) {
  $payload = [ordered]@{
    ok = ($selectedUrls.Count -gt 0)
    mode = "dry_run"
    ports = @($Port | Where-Object { $_ -gt 0 } | Sort-Object -Unique)
    filters = [ordered]@{
      max_pages = $MaxPages
      min_actions = $MinActions
      min_risk_score = $MinRiskScore
      include_gap = @($IncludeGap)
      include_restricted = [bool]$IncludeRestricted
      retry_attempted = [bool]$RetryAttempted
      retry_after_hours = $RetryAfterHours
    }
    attempt_state = [ordered]@{
      path = $StatePath
      attempts = @($attemptByRoute.Keys).Count
      skipped_recent_count = @($skippedAttempted).Count
    }
    before_report = New-ReportSummary $beforeReport
    selected_pages_count = $selectedUrls.Count
    selected_pages = $selected
    skipped_recent_pages = $skippedAttempted
    planned_command = if ($selectedUrls.Count -gt 0) {
      "powershell -ExecutionPolicy Bypass -File (Join-Path `$ZiniaoOpsHome `"scripts\learn-xinjian-weak-pages.ps1`") -MaxPages $MaxPages -Json"
    } else {
      ""
    }
    next_action = if ($selectedUrls.Count -gt 0) { "rerun_without_dry_run_to_learn_weak_pages" } else { "no_learnable_weak_pages_found_or_lower_filters" }
  }
  if ($Json) { $payload | ConvertTo-Json -Depth 16 } else {
    Write-Host ("Selected weak Xinjian pages: {0}" -f $selectedUrls.Count)
    foreach ($page in $selected) { Write-Host ("- [{0}] {1} {2}" -f $page.risk_score, $page.name, $page.url) }
  }
  if ($selectedUrls.Count -gt 0) { exit 0 }
  exit 1
}

$learned = @()
foreach ($page in $selected) {
  $args = @(Get-PortArgumentList -Ports $Port)
  $args += @("-Url", [string]$page.url, "-NoGenerate", "-Json")
  if ($SkipDom) { $args += "-SkipDom" }
  if ($SkipOverlays) { $args += "-SkipOverlays" }
  if ($SkipDialogs) { $args += "-SkipDialogs" }
  if ($SkipRowActions) { $args += "-SkipRowActions" }
  $result = Invoke-JsonScript -ScriptName "learn-xinjian-current-page.ps1" -Arguments $args
  $summary = [ordered]@{
    ok = [bool]$result.ok
    url = [string]$page.url
    route = [string]$page.route
    name = [string]$page.name
    risk_score = [int]$page.risk_score
    exit_code = [int]$result.exit_code
    captures = @()
    error = ""
  }
  if ($result.parsed) {
    if ($result.parsed.PSObject.Properties.Match("captures").Count -gt 0) { $summary.captures = @($result.parsed.captures) }
    if ($result.parsed.PSObject.Properties.Match("failures").Count -gt 0 -and @($result.parsed.failures).Count -gt 0) {
      $summary.error = "capture_step_failed"
    }
    if ($result.parsed.PSObject.Properties.Match("mode").Count -gt 0) { $summary.mode = [string]$result.parsed.mode }
  } else {
    $summary.error = "output_parse_failed"
  }
  $learned += [pscustomobject]$summary
}

$generateResult = $null
$generateSkippedReason = ""
$pageFailures = @($learned | Where-Object { !$_.ok })
if ($NoGenerate) {
  $generateSkippedReason = "no_generate_requested"
} elseif ($pageFailures.Count -gt 0) {
  $generateSkippedReason = "page_learning_failed"
} else {
  $generateResult = Invoke-JsonScript -ScriptName "learn-xinjian-current-page.ps1" -Arguments @("-GenerateOnly", "-Json")
}

$failed = @($pageFailures)
if ($generateResult -and !$generateResult.ok) {
  $failed += [pscustomobject]@{ ok = $false; url = ""; name = "generate"; error = "generate_failed"; exit_code = [int]$generateResult.exit_code }
}

$afterReport = $null
if ($failed.Count -eq 0 -and !$NoGenerate) {
  $afterReportResult = Invoke-JsonScript -ScriptName "report-xinjian-action-memory.ps1" -Arguments @(
    "-MinActions", [string]$MinActions,
    "-MaxWeakPages", "0",
    "-Json"
  )
  if ($afterReportResult.ok) { $afterReport = $afterReportResult.parsed }
}

$updatedState = Write-LearnState -ExistingState $learnState -LearnedPages $learned -GenerateSkippedReason $generateSkippedReason -BeforeReport $beforeReport -AfterReport $afterReport

$payload = [ordered]@{
  ok = ($failed.Count -eq 0)
  mode = "learn_weak_pages"
  ports = @($Port | Where-Object { $_ -gt 0 } | Sort-Object -Unique)
  filters = [ordered]@{
    max_pages = $MaxPages
    min_actions = $MinActions
    min_risk_score = $MinRiskScore
    include_gap = @($IncludeGap)
    include_restricted = [bool]$IncludeRestricted
    retry_attempted = [bool]$RetryAttempted
    retry_after_hours = $RetryAfterHours
  }
  attempt_state = [ordered]@{
    path = $StatePath
    attempts = @($updatedState.attempts).Count
    skipped_recent_count = @($skippedAttempted).Count
  }
  selected_pages_count = $selectedUrls.Count
  selected_pages = $selected
  skipped_recent_pages = $skippedAttempted
  before_report = New-ReportSummary $beforeReport
  after_report = New-ReportSummary $afterReport
  learn = [ordered]@{
    mode = "learn_weak_pages_batch"
    learned = $learned
    generate = if ($generateResult) {
      [ordered]@{
        ok = [bool]$generateResult.ok
        exit_code = [int]$generateResult.exit_code
        summary = if ($generateResult.parsed) {
          [ordered]@{
            mode = [string]$generateResult.parsed.mode
            before_actions = [int]$generateResult.parsed.before_catalog.actions
            after_actions = [int]$generateResult.parsed.after_catalog.actions
            failures = @($generateResult.parsed.failures).Count
          }
        } else { $null }
      }
    } else { $null }
    generate_skipped_reason = $generateSkippedReason
    failures = $failed
  }
  error = if ($failed.Count -eq 0) { "" } else { "weak_page_learning_failed" }
  next_action = if ($failed.Count -eq 0) { "rerun_report_or_continue_learning_next_weak_pages" } else { "inspect_failed_page_learning_steps" }
}

if ($Json) {
  $payload | ConvertTo-Json -Depth 20
} else {
  $status = if ($failed.Count -eq 0) { "ok" } else { "failed" }
  Write-Host ("Weak page learning {0}: {1} page(s)" -f $status, $selectedUrls.Count)
  foreach ($page in $selected) { Write-Host ("- [{0}] {1} {2}" -f $page.risk_score, $page.name, $page.url) }
}

if ($failed.Count -eq 0) { exit 0 }
exit 1
