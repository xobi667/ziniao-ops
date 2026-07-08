[CmdletBinding(PositionalBinding = $false)]
param(
  [Parameter(Mandatory = $true)]
  [string]$Intent,
  [string]$Url = "",
  [int[]]$Port = @(),
  [switch]$Execute,
  [switch]$AllowWrite,
  [switch]$AllowExport,
  [switch]$NoAutoDetectUrl,
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

function Get-PortArgumentList {
  param([int[]]$Ports)
  $items = @($Ports | Where-Object { $_ -gt 0 } | Sort-Object -Unique)
  $args = @()
  foreach ($item in $items) {
    $args += @("-Port", [string]$item)
  }
  return $args
}

function Get-FirstExplicitPort {
  $items = @($Port | Where-Object { $_ -gt 0 } | Sort-Object -Unique)
  if ($items.Count -gt 0) { return [int]$items[0] }
  return $null
}

function Resolve-XinjianCurrentUrlByScript {
  param([string]$QueryIntent = "")
  $resolver = Join-Path $PSScriptRoot "resolve-xinjian-current-url.ps1"
  if (!(Test-Path -LiteralPath $resolver)) {
    return [pscustomobject]@{ ok = $false; reason = "resolver_missing"; candidates = @() }
  }
  $args = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $resolver)
  $args += Get-PortArgumentList -Ports $Port
  if ($QueryIntent) { $args += @("-Intent", $QueryIntent) }
  $args += "-Json"
  $raw = @(& powershell @args 2>&1)
  $parsed = ConvertFrom-JsonText $raw
  if ($parsed) { return $parsed }
  return [pscustomobject]@{ ok = $false; reason = "resolver_output_parse_failed"; raw_output = ($raw | Out-String).Trim(); candidates = @() }
}

function Invoke-XinjianActionQuery {
  param(
    [string]$QueryIntent,
    [string]$QueryUrl
  )
  $queryArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "query-xinjian-ui-action.ps1"), "-Intent", $QueryIntent, "-Json")
  if ($QueryUrl) { $queryArgs += @("-Url", $QueryUrl) }
  $raw = @(& powershell @queryArgs 2>&1)
  [pscustomobject]@{
    raw = $raw
    exit_code = $LASTEXITCODE
    parsed = ConvertFrom-JsonText $raw
  }
}

function Resolve-XinjianUrlByIntent {
  param(
    [string]$QueryIntent,
    [object]$Detection
  )
  $urls = @($Detection.candidates |
    ForEach-Object { [string]$_.url } |
    Where-Object { Test-XinjianUrl $_ } |
    Sort-Object -Unique)
  if ($urls.Count -lt 2) { return $null }
  $scores = @()
  foreach ($candidateUrl in $urls) {
    $probe = Invoke-XinjianActionQuery -QueryIntent $QueryIntent -QueryUrl $candidateUrl
    if (!$probe.parsed -or !$probe.parsed.ok -or @($probe.parsed.matches).Count -eq 0) {
      $scores += [pscustomobject]@{
        url = $candidateUrl
        ok = $false
        score = 0
        rank = 0
        page_name = ""
        action_name = ""
      }
      continue
    }
    $best = @($probe.parsed.matches)[0]
    $scores += [pscustomobject]@{
      url = $candidateUrl
      ok = $true
      score = [int]$best.score
      rank = [int]$best.rank
      page_name = [string]$best.page_name
      action_name = [string]$best.action.name
    }
  }
  $ordered = @($scores | Sort-Object @{ Expression = "score"; Descending = $true }, @{ Expression = "rank"; Descending = $true })
  if ($ordered.Count -eq 0 -or !$ordered[0].ok -or $ordered[0].score -le 0) { return $null }
  if ($ordered.Count -gt 1 -and $ordered[1].ok -and $ordered[1].score -eq $ordered[0].score -and $ordered[1].rank -eq $ordered[0].rank) {
    return $null
  }
  return [pscustomobject]@{
    url = [string]$ordered[0].url
    score = [int]$ordered[0].score
    rank = [int]$ordered[0].rank
    page_name = [string]$ordered[0].page_name
    action_name = [string]$ordered[0].action_name
    candidates = @($ordered)
  }
}

function Get-ForegroundProcessId {
  try {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class ZiniaoOpsNativeWindow {
  [DllImport("user32.dll")]
  public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")]
  public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
}
"@ -ErrorAction SilentlyContinue | Out-Null
    $processIdValue = [uint32]0
    $handle = [ZiniaoOpsNativeWindow]::GetForegroundWindow()
    if ($handle -eq [IntPtr]::Zero) { return $null }
    [void][ZiniaoOpsNativeWindow]::GetWindowThreadProcessId($handle, [ref]$processIdValue)
    if ($processIdValue -gt 0) { return [int]$processIdValue }
  } catch {
  }
  return $null
}

function Test-XinjianUrl([string]$Value) {
  $text = [string]$Value
  return $text -match "^https?://erp\.xinjianerp\.com/" -and $text -notmatch "\s"
}

function Resolve-XinjianCurrentUrl([int]$CdpPort) {
  $result = [ordered]@{
    ok = $false
    url = ""
    source = ""
    confidence = "none"
    reason = ""
    candidates = @()
  }
  $detector = Join-Path $PSScriptRoot "detect-ziniao-windows.ps1"
  if (!(Test-Path -LiteralPath $detector)) {
    $result.reason = "detector_missing"
    return [pscustomobject]$result
  }

  $raw = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $detector -Port $CdpPort -Json 2>&1)
  $detected = ConvertFrom-JsonText $raw
  if (!$detected -or !$detected.ok) {
    $result.reason = "detector_failed"
    return [pscustomobject]$result
  }

  $foregroundPid = Get-ForegroundProcessId
  $windows = @($detected.windows | Where-Object {
      $_.platform -eq "xinjian_erp" -and $_.page_url -and (Test-XinjianUrl ([string]$_.page_url))
    })
  $visible = @($windows | Where-Object { $_.source -in @("window_uia", "window_title") })
  $visibleCandidates = @($visible | Select-Object -First 8 | ForEach-Object {
      [ordered]@{
        source = $_.source
        process_id = $_.process_id
        title = $_.page_title
        url = $_.page_url
        is_foreground_process = ($foregroundPid -and $_.process_id -eq $foregroundPid)
      }
    })
  $result.candidates = @($visibleCandidates)

  $foreground = @($visible | Where-Object { $foregroundPid -and $_.process_id -eq $foregroundPid } | Select-Object -First 1)
  if ($foreground.Count -gt 0) {
    $result.ok = $true
    $result.url = [string]$foreground[0].page_url
    $result.source = [string]$foreground[0].source
    $result.confidence = "foreground_window_url"
    return [pscustomobject]$result
  }

  $uniqueVisibleUrls = @($visible | ForEach-Object { [string]$_.page_url } | Where-Object { $_ } | Sort-Object -Unique)
  if ($uniqueVisibleUrls.Count -eq 1) {
    $result.ok = $true
    $result.url = [string]$uniqueVisibleUrls[0]
    $result.source = "visible_window_url"
    $result.confidence = "single_visible_xinjian_window"
    return [pscustomobject]$result
  }

  $uniqueCdpUrls = @()
  try {
    $body = (Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:$CdpPort/json" -TimeoutSec 5).Content
    $parsedPages = $body | ConvertFrom-Json
    $pages = @($parsedPages | ForEach-Object { $_ })
    $uniqueCdpUrls = @($pages |
      Where-Object { $_.type -eq "page" -and (Test-XinjianUrl ([string]$_.url)) } |
      ForEach-Object { [string]$_.url } |
      Sort-Object -Unique)
  } catch {
    $uniqueCdpUrls = @()
  }
  if ($uniqueCdpUrls.Count -eq 1) {
    $result.ok = $true
    $result.url = [string]$uniqueCdpUrls[0]
    $result.source = "cdp_page_url"
    $result.confidence = "single_debuggable_xinjian_page"
    return [pscustomobject]$result
  }

  $knownCandidateUrls = @($result.candidates | ForEach-Object { [string]$_.url } | Where-Object { $_ })
  foreach ($cdpUrl in $uniqueCdpUrls) {
    if ($knownCandidateUrls -contains $cdpUrl) { continue }
    $result.candidates += [ordered]@{
      source = "cdp_page_url"
      process_id = $null
      title = ""
      url = $cdpUrl
      is_foreground_process = $false
    }
  }

  $result.reason = if ($uniqueVisibleUrls.Count -gt 1 -or $uniqueCdpUrls.Count -gt 1) { "ambiguous_xinjian_windows" } else { "no_xinjian_window" }
  return [pscustomobject]$result
}

function Get-SafetyMode([string]$Safety) {
  if ($Safety -like "confirmation_required_export*") { return "confirmation_required_export" }
  if ($Safety -like "confirmation_required*") { return "confirmation_required_write" }
  if ($Safety -in @("read_filter", "navigation", "view_setting", "account_menu", "opens_dialog_no_submit", "form_field")) { return "safe_execute_allowed" }
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

$requestedUrl = $Url
$urlDetection = $null
if (!$Url -and !$NoAutoDetectUrl) {
  $urlDetection = Resolve-XinjianCurrentUrlByScript -QueryIntent $Intent
  if ($urlDetection.ok -and $urlDetection.url) {
    $Url = [string]$urlDetection.url
  }
} elseif ($Url) {
  $urlDetection = Resolve-XinjianCurrentUrlByScript
}

$effectivePort = Get-FirstExplicitPort
if (!$effectivePort -and $urlDetection -and $urlDetection.PSObject.Properties.Match("resolved_port").Count -gt 0 -and $urlDetection.resolved_port) {
  $effectivePort = [int]$urlDetection.resolved_port
}

$queryResult = Invoke-XinjianActionQuery -QueryIntent $Intent -QueryUrl $Url
$queryRaw = $queryResult.raw
$queryExit = $queryResult.exit_code
$query = $queryResult.parsed
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
    requested_url = $requestedUrl
    url_detection = $urlDetection
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
$requiresPageContext = !$Url
$requiresCdpPort = !$effectivePort
$canExecute = !$unknownSafety -and !$requiresRowContext -and !$requiresPageContext -and !$requiresCdpPort -and (!$requiresExport -or $AllowExport -or $AllowWrite) -and (!$requiresWrite -or $AllowWrite)

$plan = [ordered]@{
  intent = $Intent
  url = $Url
  requested_url = $requestedUrl
  url_detection = $urlDetection
  ports = @($Port | Where-Object { $_ -gt 0 } | Sort-Object -Unique)
  resolved_port = $effectivePort
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
  safety_note = if ($requiresCdpPort) {
    "No debuggable Xinjian CDP port was resolved. Dry-run only; open or log in to Xinjian in a Chrome/Edge/Ziniao window with DevTools enabled."
  } elseif ($requiresPageContext -and $requiresWrite) {
    "Write/delete/save/submit-like action and no current Xinjian URL was resolved. Pass -Url or focus the target Xinjian window, then use -Execute -AllowWrite only after explicit confirmation."
  } elseif ($requiresPageContext -and $requiresExport) {
    "Export/download action and no current Xinjian URL was resolved. Pass -Url or focus the target Xinjian window, then use -Execute -AllowExport only after explicit confirmation."
  } elseif ($requiresPageContext) {
    "No current Xinjian URL was resolved. Dry-run only; bring the target Xinjian window to the foreground or pass -Url to execute."
  } elseif ($requiresRowContext) {
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
    next_action = if ($requiresCdpPort) { "open_or_login_debuggable_xinjian_browser" } elseif ($requiresPageContext -and $requiresWrite) { "focus_target_xinjian_window_or_pass_url_then_confirm_write" } elseif ($requiresPageContext -and $requiresExport) { "focus_target_xinjian_window_or_pass_url_then_confirm_export" } elseif ($requiresPageContext) { "focus_target_xinjian_window_or_pass_url" } elseif ($requiresRowContext) { "provide_row_context_or_capture_row_action_buttons" } elseif ($requiresWrite) { "rerun_with_execute_allow_write_after_explicit_confirmation" } elseif ($requiresExport) { "rerun_with_execute_allow_export_after_explicit_confirmation" } else { "manual_review_action_safety" }
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

$argsList = @($helper, "--port", [string]$effectivePort, "--action-file", $actionPath)
if ($Url) { $argsList += @("--match-url", $Url) }
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
