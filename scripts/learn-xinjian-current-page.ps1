[CmdletBinding(PositionalBinding = $false)]
param(
  [string]$Url = "",
  [int[]]$Port = @(),
  [string]$Intent = "",
  [switch]$NoAutoDetectUrl,
  [switch]$SkipDom,
  [switch]$SkipOverlays,
  [switch]$SkipDialogs,
  [switch]$SkipRowActions,
  [switch]$GenerateOnly,
  [switch]$NoGenerate,
  [int]$MaxOverlayTriggers = 40,
  [int]$MaxDialogTriggers = 20,
  [int]$MaxTables = 12,
  [switch]$IncludeStepResults,
  [switch]$DryRun,
  [switch]$Json
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$catalogPath = Join-Path $root "references\xinjian-ui-action-catalog.json"

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

function Get-CatalogSummary {
  if (!(Test-Path -LiteralPath $catalogPath)) {
    return [ordered]@{
      exists = $false
      pages = 0
      actions = 0
      safe_execute_allowed = 0
      confirmation_required_write = 0
      confirmation_required_export = 0
    }
  }
  try {
    $catalog = Get-Content -LiteralPath $catalogPath -Raw -Encoding UTF8 | ConvertFrom-Json
    return [ordered]@{
      exists = $true
      version = [string]$catalog.version
      pages = [int]$catalog.totals.pages
      actions = [int]$catalog.totals.actions
      safe_execute_allowed = [int]$catalog.totals.safety_counts.safe_execute_allowed
      confirmation_required_write = [int]$catalog.totals.safety_counts.confirmation_required_write
      confirmation_required_export = [int]$catalog.totals.safety_counts.confirmation_required_export
    }
  } catch {
    return [ordered]@{
      exists = $false
      error = $_.Exception.Message
      pages = 0
      actions = 0
      safe_execute_allowed = 0
      confirmation_required_write = 0
      confirmation_required_export = 0
    }
  }
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

function Test-XinjianLoginOrRestrictedUrl([string]$InputUrl) {
  $route = Get-RouteKey $InputUrl
  if (!$route) { return $true }
  return $route -match "^/(login|xtlogin|sso|social-login|401|404|redirect)(/|$)" -or
    $route -match "^/index/(noaccess|ad-no-auth)(/|$)"
}

function Get-ResolvedPort($Resolution, $FallbackPort = $null) {
  $explicitPorts = @($Port | Where-Object { $_ -gt 0 } | Sort-Object -Unique)
  if ($explicitPorts.Count -gt 0) { return [int]$explicitPorts[0] }
  if ($FallbackPort) { return [int]$FallbackPort }
  if ($Resolution -and $Resolution.PSObject.Properties.Match("resolved_port").Count -gt 0 -and $Resolution.resolved_port) {
    return [int]$Resolution.resolved_port
  }
  return $null
}

function Get-ResolvedTitle($Resolution, [string]$InputUrl) {
  if (!$Resolution -or !$InputUrl -or $Resolution.PSObject.Properties.Match("candidates").Count -eq 0) { return "" }
  $match = @($Resolution.candidates | Where-Object { [string]$_.url -eq $InputUrl } | Select-Object -First 1)
  if ($match.Count -gt 0) { return [string]$match[0].title }
  return ""
}

function Get-XinjianPageKind([string]$InputUrl) {
  if (!$InputUrl) { return "unknown" }
  $route = Get-RouteKey $InputUrl
  if ($route -match "^/(login|xtlogin|sso|social-login|redirect)(/|$)") { return "login_page" }
  if ($route -match "^/(401|404)(/|$)" -or $route -match "^/index/(noaccess|ad-no-auth)(/|$)") { return "non_business_page" }
  return "business_page"
}

function Resolve-CapturePort {
  param(
    [string]$TargetUrl,
    [object]$UrlResolution
  )

  $explicit = @($Port | Where-Object { $_ -gt 0 } | Sort-Object -Unique)
  if ($explicit.Count -gt 0) {
    return [pscustomobject]@{
      ok = $true
      port = [int]$explicit[0]
      reason = "explicit_port"
      candidates = @()
    }
  }

  if ($UrlResolution -and $UrlResolution.PSObject.Properties.Match("resolved_port").Count -gt 0 -and $UrlResolution.resolved_port) {
    return [pscustomobject]@{
      ok = $true
      port = [int]$UrlResolution.resolved_port
      reason = "resolved_current_url_port"
      candidates = @($UrlResolution.candidates)
    }
  }

  $detector = Join-Path $PSScriptRoot "detect-ziniao-windows.ps1"
  if (!(Test-Path -LiteralPath $detector)) {
    return [pscustomobject]@{ ok = $false; port = $null; reason = "detector_missing"; candidates = @() }
  }

  $raw = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $detector -Json 2>&1)
  $detected = ConvertFrom-JsonText $raw
  if (!$detected -or !$detected.ok) {
    return [pscustomobject]@{ ok = $false; port = $null; reason = "detector_failed"; raw_output = ($raw | Out-String).Trim(); candidates = @() }
  }

  $targetRoute = Get-RouteKey $TargetUrl
  $candidates = @($detected.windows | Where-Object {
      $_.source -eq "cdp" -and
      $_.platform -eq "xinjian_erp" -and
      $_.reachable -and
      $_.port -and
      $_.page_url
    } | Select-Object source, port, process_name, process_id, page_title, page_url, login_signal)

  if ($candidates.Count -eq 0) {
    return [pscustomobject]@{ ok = $false; port = $null; reason = "no_debuggable_xinjian_page"; candidates = @() }
  }

  $exact = @($candidates | Where-Object {
      (Get-RouteKey ([string]$_.page_url)) -eq $targetRoute -and
      !(Test-XinjianLoginOrRestrictedUrl ([string]$_.page_url))
    } | Select-Object -First 1)
  if ($exact.Count -gt 0) {
    return [pscustomobject]@{ ok = $true; port = [int]$exact[0].port; reason = "matched_target_route"; candidates = @($candidates) }
  }

  $loggedIn = @($candidates | Where-Object {
      !(Test-XinjianLoginOrRestrictedUrl ([string]$_.page_url))
    } | Select-Object -First 1)
  if ($loggedIn.Count -gt 0) {
    return [pscustomobject]@{ ok = $true; port = [int]$loggedIn[0].port; reason = "reuse_logged_in_xinjian_port"; candidates = @($candidates) }
  }

  return [pscustomobject]@{
    ok = $false
    port = $null
    reason = "xinjian_cdp_pages_are_login_or_restricted"
    candidates = @($candidates)
  }
}

function New-StepSummary {
  param(
    [string]$Name,
    [object]$Result
  )
  $parsed = $Result.parsed
  $item = [ordered]@{
    name = $Name
    script = [string]$Result.script
    ok = [bool]$Result.ok
    exit_code = [int]$Result.exit_code
    error = ""
    output_path = ""
    counts = $null
    summary = [ordered]@{}
  }
  if ($parsed) {
    if ($parsed.PSObject.Properties.Match("error").Count -gt 0) { $item.error = [string]$parsed.error }
    if ($parsed.PSObject.Properties.Match("output_path").Count -gt 0) { $item.output_path = [string]$parsed.output_path }
    if ($parsed.PSObject.Properties.Match("counts").Count -gt 0) { $item.counts = $parsed.counts }
    foreach ($name in @("files", "considered", "promoted", "skipped_curated", "skipped_invalid", "pages", "actions", "dry_run")) {
      if ($parsed.PSObject.Properties.Match($name).Count -gt 0) {
        $item.summary[$name] = $parsed.$name
      }
    }
    if ($parsed.PSObject.Properties.Match("matched_page").Count -gt 0) {
      $item.summary["matched_page"] = $parsed.matched_page
    }
  } elseif ($Result.raw_output) {
    $item.error = "output_parse_failed"
  }
  if ($IncludeStepResults) {
    $item["result"] = $parsed
  }
  return $item
}

function Add-CaptureRouteValidation {
  param(
    [object[]]$Steps,
    [string]$TargetUrl
  )
  $expectedRoute = Get-RouteKey $TargetUrl
  if (!$expectedRoute) { return @($Steps) }

  foreach ($step in @($Steps)) {
    if (!$step.ok) { continue }
    $matchedPage = $null
    if ($step.summary -and $step.summary.Contains("matched_page")) {
      $matchedPage = $step.summary["matched_page"]
    }
    if (!$matchedPage -or !$matchedPage.url) { continue }

    $actualRoute = Get-RouteKey ([string]$matchedPage.url)
    if ($actualRoute -and $actualRoute -ne $expectedRoute) {
      $step["ok"] = $false
      $step["error"] = "matched_page_url_mismatch"
      $step.summary["expected_route"] = $expectedRoute
      $step.summary["actual_route"] = $actualRoute
      $step.summary["validation"] = "failed"
    } else {
      $step.summary["expected_route"] = $expectedRoute
      $step.summary["actual_route"] = $actualRoute
      $step.summary["validation"] = "matched_target_route"
    }
  }

  return @($Steps)
}

$requestedUrl = $Url
$urlResolution = $null
if (!$Url -and !$NoAutoDetectUrl -and !$GenerateOnly) {
  $resolveArgs = @(Get-PortArgumentList -Ports $Port)
  $resolveArgs += "-Json"
  if ($Intent) { $resolveArgs += @("-Intent", $Intent) }
  $resolveResult = Invoke-JsonScript -ScriptName "resolve-xinjian-current-url.ps1" -Arguments $resolveArgs
  $urlResolution = $resolveResult.parsed
  if ($resolveResult.ok -and $urlResolution -and $urlResolution.url) {
    $Url = [string]$urlResolution.url
  }
}

if (!$Url -and !$GenerateOnly) {
  $payload = [ordered]@{
    ok = $false
    mode = "current_page_unresolved"
    requested_url = $requestedUrl
    current_url = ""
    current_title = ""
    resolved_port = Get-ResolvedPort $urlResolution
    page_kind = "unknown"
    url_resolution = $urlResolution
    next_action = "focus_the_target_xinjian_window_or_pass_url"
  }
  if ($Json) { $payload | ConvertTo-Json -Depth 12 } else { Write-Host "No current Xinjian page URL was resolved. Pass -Url or focus the target Xinjian window." }
  exit 1
}

$before = Get-CatalogSummary

if (!$GenerateOnly -and (Test-XinjianLoginOrRestrictedUrl $Url)) {
  $route = Get-RouteKey $Url
  $nextAction = if ($route -match "^/(login|xtlogin|sso|social-login|redirect)(/|$)") {
    "manual_login_required_in_debuggable_xinjian_browser"
  } else {
    "open_valid_xinjian_business_page"
  }
  $payload = [ordered]@{
    ok = $false
    mode = "non_business_xinjian_page"
    requested_url = $requestedUrl
    url = $Url
    current_url = $Url
    current_title = Get-ResolvedTitle -Resolution $urlResolution -InputUrl $Url
    resolved_port = Get-ResolvedPort $urlResolution
    page_kind = Get-XinjianPageKind $Url
    url_resolution = $urlResolution
    before_catalog = $before
    next_action = $nextAction
  }
  if ($Json) { $payload | ConvertTo-Json -Depth 12 } else { Write-Host ("Current Xinjian page is not learnable: {0}" -f $Url) }
  exit 1
}

$capturePortResolution = $null
$capturePort = $null
if (!$GenerateOnly) {
  $capturePortResolution = Resolve-CapturePort -TargetUrl $Url -UrlResolution $urlResolution
  if ($capturePortResolution.ok -and $capturePortResolution.port) {
    $capturePort = [int]$capturePortResolution.port
  }
}

if (!$GenerateOnly -and !$DryRun -and !$capturePort) {
  $payload = [ordered]@{
    ok = $false
    mode = "cdp_port_unresolved"
    requested_url = $requestedUrl
    url = $Url
    current_url = $Url
    current_title = Get-ResolvedTitle -Resolution $urlResolution -InputUrl $Url
    resolved_port = Get-ResolvedPort $urlResolution
    page_kind = Get-XinjianPageKind $Url
    url_resolution = $urlResolution
    capture_port_resolution = $capturePortResolution
    before_catalog = $before
    next_action = if ($capturePortResolution -and $capturePortResolution.reason -eq "xinjian_cdp_pages_are_login_or_restricted") {
      "manual_login_required_in_debuggable_xinjian_browser"
    } else {
      "open_or_focus_a_debuggable_xinjian_browser"
    }
  }
  if ($Json) { $payload | ConvertTo-Json -Depth 14 } else { Write-Host ("No usable Xinjian CDP port was resolved: {0}" -f $capturePortResolution.reason) }
  exit 1
}

$planned = @()
if (!$GenerateOnly) {
  if (!$SkipDom) { $planned += "capture_dom_controls" }
  if (!$SkipOverlays) { $planned += "capture_overlay_dropdowns" }
  if (!$SkipDialogs) { $planned += "capture_safe_dialog_controls" }
  if (!$SkipRowActions) { $planned += "capture_table_row_actions_without_row_values" }
}
if (!$NoGenerate) {
  $planned += "regenerate_public_action_maps"
  $planned += "regenerate_unified_action_catalog"
}

if ($DryRun) {
  $payload = [ordered]@{
    ok = $true
    mode = "dry_run"
    url = $Url
    current_url = $Url
    current_title = Get-ResolvedTitle -Resolution $urlResolution -InputUrl $Url
    resolved_port = Get-ResolvedPort $urlResolution $capturePort
    page_kind = Get-XinjianPageKind $Url
    requested_url = $requestedUrl
    url_resolution = $urlResolution
    capture_port = $capturePort
    capture_port_resolution = $capturePortResolution
    before_catalog = $before
    planned_steps = $planned
    safety = [ordered]@{
      dom = "read visible DOM controls only"
      overlays = "open overlay panels and close them; do not click overlay items"
      dialogs = "open safe dialog/drawer openers only; do not click submit/save/confirm"
      row_actions = "read table headers and row action labels only; do not read row cell values"
    }
  }
  if ($Json) { $payload | ConvertTo-Json -Depth 12 } else { Write-Host ("Would learn Xinjian page: {0}" -f $Url); $planned | ForEach-Object { Write-Host ("- {0}" -f $_) } }
  exit 0
}

$captures = @()
if (!$GenerateOnly) {
  if (!$SkipDom) {
    $captures += New-StepSummary -Name "capture_dom_controls" -Result (Invoke-JsonScript -ScriptName "capture-xinjian-dom-map.ps1" -Arguments @("-Port", [string]$capturePort, "-Url", $Url, "-Json"))
  }
  if (!$SkipOverlays) {
    $captures += New-StepSummary -Name "capture_overlay_dropdowns" -Result (Invoke-JsonScript -ScriptName "capture-xinjian-overlays.ps1" -Arguments @("-Port", [string]$capturePort, "-Url", $Url, "-MaxTriggers", [string]$MaxOverlayTriggers, "-IncludeSelects", "-IncludeDatePickers", "-Json"))
  }
  if (!$SkipDialogs) {
    $captures += New-StepSummary -Name "capture_safe_dialog_controls" -Result (Invoke-JsonScript -ScriptName "capture-xinjian-dialogs.ps1" -Arguments @("-Port", [string]$capturePort, "-Url", $Url, "-MaxTriggers", [string]$MaxDialogTriggers, "-Json"))
  }
  if (!$SkipRowActions) {
    $captures += New-StepSummary -Name "capture_table_row_actions" -Result (Invoke-JsonScript -ScriptName "capture-xinjian-row-actions.ps1" -Arguments @("-Port", [string]$capturePort, "-Url", $Url, "-MaxTables", [string]$MaxTables, "-Json"))
  }
  $captures = @(Add-CaptureRouteValidation -Steps $captures -TargetUrl $Url)
}

$generators = @()
$captureFailures = @($captures | Where-Object { !$_.ok })
if (!$NoGenerate -and $captureFailures.Count -eq 0) {
  $generators += New-StepSummary -Name "generate_auto_map" -Result (Invoke-JsonScript -ScriptName "generate-xinjian-ui-auto-map.ps1" -Arguments @("-Json"))
  $generators += New-StepSummary -Name "generate_overlay_map" -Result (Invoke-JsonScript -ScriptName "generate-xinjian-ui-overlay-map.ps1" -Arguments @("-Json"))
  $generators += New-StepSummary -Name "generate_dialog_map" -Result (Invoke-JsonScript -ScriptName "generate-xinjian-ui-dialog-map.ps1" -Arguments @("-Json"))
  $generators += New-StepSummary -Name "generate_row_action_map" -Result (Invoke-JsonScript -ScriptName "generate-xinjian-ui-row-action-map.ps1" -Arguments @("-Json"))
  $generators += New-StepSummary -Name "generate_action_catalog" -Result (Invoke-JsonScript -ScriptName "generate-xinjian-ui-action-catalog.ps1" -Arguments @("-Json"))
}

$after = Get-CatalogSummary
$pageActionSummary = $null
if ($Url -and !$NoGenerate) {
  $listResult = Invoke-JsonScript -ScriptName "list-xinjian-page-actions.ps1" -Arguments @("-Url", $Url, "-Json")
  if ($listResult.ok -and $listResult.parsed) {
    $pageActionSummary = [ordered]@{
      ok = $true
      page = $listResult.parsed.page
      counts = $listResult.parsed.counts
    }
  } else {
    $pageActionSummary = [ordered]@{
      ok = $false
      error = if ($listResult.parsed -and $listResult.parsed.error) { [string]$listResult.parsed.error } else { "page_actions_unavailable" }
    }
  }
}

$allSteps = @($captures + $generators)
$failed = @($allSteps | Where-Object { !$_.ok })
$payload = [ordered]@{
  ok = ($failed.Count -eq 0)
  mode = if ($GenerateOnly) { "generate_only" } else { "learn_current_page" }
  url = $Url
  current_url = $Url
  current_title = Get-ResolvedTitle -Resolution $urlResolution -InputUrl $Url
  resolved_port = Get-ResolvedPort $urlResolution $capturePort
  page_kind = Get-XinjianPageKind $Url
  requested_url = $requestedUrl
  url_resolution = $urlResolution
  capture_port = $capturePort
  capture_port_resolution = $capturePortResolution
  before_catalog = $before
  after_catalog = $after
  delta = [ordered]@{
    pages = ([int]$after.pages - [int]$before.pages)
    actions = ([int]$after.actions - [int]$before.actions)
    safe_execute_allowed = ([int]$after.safe_execute_allowed - [int]$before.safe_execute_allowed)
    confirmation_required_write = ([int]$after.confirmation_required_write - [int]$before.confirmation_required_write)
    confirmation_required_export = ([int]$after.confirmation_required_export - [int]$before.confirmation_required_export)
  }
  captures = $captures
  generators = $generators
  current_page_actions = $pageActionSummary
  failures = $failed
  next_action = if ($failed.Count -eq 0) { "use_list_or_invoke_xinjian_page_actions" } else { "inspect_failed_capture_or_generator_step" }
}

if ($Json) {
  $payload | ConvertTo-Json -Depth 18
} else {
  Write-Host ("Learned Xinjian page: {0}" -f $(if ($Url) { $Url } else { "(generate only)" }))
  Write-Host ("Catalog actions: {0} -> {1} (delta {2})" -f $before.actions, $after.actions, $payload.delta.actions)
  foreach ($step in $allSteps) {
    $status = if ($step.ok) { "ok" } else { "failed" }
    Write-Host ("[{0}] {1}" -f $status, $step.name)
  }
  if ($pageActionSummary -and $pageActionSummary.ok) {
    Write-Host ("Current page actions: {0} total, {1} safe, {2} write, {3} export" -f $pageActionSummary.counts.total, $pageActionSummary.counts.safe_execute_allowed, $pageActionSummary.counts.confirmation_required_write, $pageActionSummary.counts.confirmation_required_export)
  }
}

if ($failed.Count -eq 0) { exit 0 }
exit 1
