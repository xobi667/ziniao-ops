[CmdletBinding(PositionalBinding = $false)]
param(
  [string[]]$Url = @(),
  [int[]]$Port = @(),
  [int]$MaxPages = 0,
  [switch]$SkipDom,
  [switch]$SkipOverlays,
  [switch]$SkipDialogs,
  [switch]$SkipRowActions,
  [switch]$NoGenerate,
  [switch]$IncludeDuplicateRoutes,
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

function Test-XinjianUrl([string]$Value) {
  $text = [string]$Value
  return $text -match "^https?://erp\.xinjianerp\.com/" -and
    $text -notmatch "\s" -and
    $text -notmatch "/(?:login|xtlogin|sso|social-login|redirect|401|404)(?:$|[?#/])" -and
    $text -notmatch "/index/(?:noaccess|ad-no-auth)(?:$|[?#/])"
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
    return ([string]$InputUrl).ToLowerInvariant()
  }
}

function Get-CatalogSummary {
  if (!(Test-Path -LiteralPath $catalogPath)) {
    return [ordered]@{ exists = $false; pages = 0; actions = 0; safe_execute_allowed = 0; confirmation_required_write = 0; confirmation_required_export = 0 }
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
    return [ordered]@{ exists = $false; error = $_.Exception.Message; pages = 0; actions = 0; safe_execute_allowed = 0; confirmation_required_write = 0; confirmation_required_export = 0 }
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

function Get-ExplicitPorts {
  return @($Port | Where-Object { $_ -gt 0 } | Sort-Object -Unique)
}

function Get-OpenXinjianPages {
  $pages = @()
  $explicitPorts = @(Get-ExplicitPorts)
  if ($explicitPorts.Count -gt 0) {
    foreach ($probePort in $explicitPorts) {
      try {
        $body = (Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:$probePort/json" -TimeoutSec 5).Content
        $parsedPages = $body | ConvertFrom-Json
        foreach ($page in @($parsedPages | ForEach-Object { $_ })) {
          if ($page.type -ne "page") { continue }
          if (!(Test-XinjianUrl ([string]$page.url))) { continue }
          $pages += [pscustomobject]@{
            url = [string]$page.url
            title = [string]$page.title
            source = "cdp_page_url"
            port = [int]$probePort
          }
        }
      } catch {
      }
    }
    return @($pages)
  }

  $detected = Invoke-JsonScript -ScriptName "detect-ziniao-windows.ps1" -Arguments @("-Json")
  if (!$detected.parsed) { return @() }
  foreach ($window in @($detected.parsed.windows)) {
    if ([string]$window.platform -ne "xinjian_erp") { continue }
    if (!$window.port -or ![bool]$window.reachable) { continue }
    if (!(Test-XinjianUrl ([string]$window.page_url))) { continue }
    $pages += [pscustomobject]@{
      url = [string]$window.page_url
      title = [string]$window.page_title
      source = [string]$window.source
      port = [int]$window.port
    }
  }
  return @($pages)
}

$candidatePages = @()
foreach ($item in @($Url)) {
  if (Test-XinjianUrl $item) {
    $candidatePages += [pscustomobject]@{ url = [string]$item; title = ""; source = "argument"; port = $null }
  }
}
if ($candidatePages.Count -eq 0) {
  $candidatePages = @(Get-OpenXinjianPages)
}

$dedupedPages = @()
$seen = @{}
foreach ($page in @($candidatePages | Sort-Object source, title, url)) {
  $key = if ($IncludeDuplicateRoutes) { ([string]$page.url).ToLowerInvariant() } else { Get-RouteKey ([string]$page.url) }
  if (!$key -or $seen.ContainsKey($key)) { continue }
  $seen[$key] = $true
  $dedupedPages += $page
}
if ($MaxPages -gt 0) {
  $dedupedPages = @($dedupedPages | Select-Object -First $MaxPages)
}

$before = Get-CatalogSummary
$effectivePorts = @(Get-ExplicitPorts)
if ($effectivePorts.Count -eq 0) {
  $effectivePorts = @($dedupedPages | Where-Object { $_.port } | ForEach-Object { [int]$_.port } | Sort-Object -Unique)
}
$capturePlan = @()
if (!$SkipDom) { $capturePlan += "capture_dom_controls" }
if (!$SkipOverlays) { $capturePlan += "capture_overlay_dropdowns" }
if (!$SkipDialogs) { $capturePlan += "capture_safe_dialog_controls" }
if (!$SkipRowActions) { $capturePlan += "capture_table_row_actions_without_row_values" }

if ($DryRun) {
  $payload = [ordered]@{
    ok = ($dedupedPages.Count -gt 0)
    mode = "dry_run"
    port = if ($effectivePorts.Count -eq 1) { [int]$effectivePorts[0] } else { $null }
    ports = @($effectivePorts)
    pages = @($dedupedPages)
    pages_count = $dedupedPages.Count
    planned_pages = @($dedupedPages | ForEach-Object {
        [ordered]@{
          url = [string]$_.url
          title = [string]$_.title
          source = [string]$_.source
          port = if ($_.port) { [int]$_.port } else { $null }
          route = Get-RouteKey ([string]$_.url)
        }
      })
    before_catalog = $before
    per_page_steps = $capturePlan
    final_generate = !$NoGenerate
    next_action = if ($dedupedPages.Count -gt 0) { "rerun_without_dry_run_to_learn_open_pages" } else { "make_existing_mcp_or_debug_browser_available_or_pass_url" }
  }
  if ($Json) { $payload | ConvertTo-Json -Depth 12 } else {
    Write-Host ("Would learn {0} Xinjian page(s)." -f $dedupedPages.Count)
    foreach ($page in $dedupedPages) { Write-Host ("- {0} {1}" -f $page.title, $page.url) }
  }
  if ($dedupedPages.Count -gt 0) { exit 0 }
  exit 1
}

if ($dedupedPages.Count -eq 0) {
  $payload = [ordered]@{
    ok = $false
    mode = "no_open_xinjian_pages"
    port = if ($effectivePorts.Count -eq 1) { [int]$effectivePorts[0] } else { $null }
    ports = @($effectivePorts)
    before_catalog = $before
    next_action = "make_existing_mcp_or_debug_browser_available_or_pass_url"
  }
  if ($Json) { $payload | ConvertTo-Json -Depth 8 } else { Write-Host "No debuggable Xinjian pages were found." }
  exit 1
}

$learned = @()
foreach ($page in $dedupedPages) {
  $learnPorts = if ($page.port) { @([int]$page.port) } else { @(Get-ExplicitPorts) }
  $args = @("-Url", [string]$page.url)
  $args += Get-PortArgumentList -Ports $learnPorts
  $args += @("-NoGenerate", "-Json")
  if ($SkipDom) { $args += "-SkipDom" }
  if ($SkipOverlays) { $args += "-SkipOverlays" }
  if ($SkipDialogs) { $args += "-SkipDialogs" }
  if ($SkipRowActions) { $args += "-SkipRowActions" }
  $result = Invoke-JsonScript -ScriptName "learn-xinjian-current-page.ps1" -Arguments $args
  $summary = [ordered]@{
    ok = [bool]$result.ok
    url = [string]$page.url
    title = [string]$page.title
    source = [string]$page.source
    port = if ($page.port) { [int]$page.port } else { $null }
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
  $learned += $summary
}

$generateResult = $null
$generateSkippedReason = ""
$preGenerateFailed = @($learned | Where-Object { !$_.ok })
if ($NoGenerate) {
  $generateSkippedReason = "no_generate_requested"
} elseif ($preGenerateFailed.Count -gt 0) {
  $generateSkippedReason = "page_learning_failed"
} else {
  $generateResult = Invoke-JsonScript -ScriptName "learn-xinjian-current-page.ps1" -Arguments @("-GenerateOnly", "-Json")
}

$after = Get-CatalogSummary
$failed = @($learned | Where-Object { !$_.ok })
if ($generateResult -and !$generateResult.ok) { $failed += [ordered]@{ ok = $false; url = ""; title = "generate"; error = "generate_failed"; exit_code = $generateResult.exit_code } }
$successful = @($learned | Where-Object { $_.ok })
$payload = [ordered]@{
  ok = ($failed.Count -eq 0)
  mode = "learn_open_pages"
  port = if ($effectivePorts.Count -eq 1) { [int]$effectivePorts[0] } else { $null }
  ports = @($effectivePorts)
  pages_count = $dedupedPages.Count
  success_count = $successful.Count
  failed_count = $failed.Count
  learned_pages = @($learned | ForEach-Object {
      [ordered]@{
        ok = [bool]$_.ok
        url = [string]$_.url
        title = [string]$_.title
        source = [string]$_.source
        port = if ($_.port) { [int]$_.port } else { $null }
        route = Get-RouteKey ([string]$_.url)
        exit_code = [int]$_.exit_code
        capture_steps = @($_.captures).Count
        error = [string]$_.error
      }
    })
  before_catalog = $before
  after_catalog = $after
  delta = [ordered]@{
    pages = ([int]$after.pages - [int]$before.pages)
    actions = ([int]$after.actions - [int]$before.actions)
    safe_execute_allowed = ([int]$after.safe_execute_allowed - [int]$before.safe_execute_allowed)
    confirmation_required_write = ([int]$after.confirmation_required_write - [int]$before.confirmation_required_write)
    confirmation_required_export = ([int]$after.confirmation_required_export - [int]$before.confirmation_required_export)
  }
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
  next_action = if ($failed.Count -eq 0) { "inspect_catalog_or_invoke_actions" } else { "inspect_failed_page_learning_steps" }
}

if ($Json) {
  $payload | ConvertTo-Json -Depth 18
} else {
  Write-Host ("Learned {0} Xinjian page(s)." -f $dedupedPages.Count)
  Write-Host ("Catalog actions: {0} -> {1} (delta {2})" -f $before.actions, $after.actions, $payload.delta.actions)
  foreach ($item in $learned) {
    $status = if ($item.ok) { "ok" } else { "failed" }
    Write-Host ("[{0}] {1}" -f $status, $item.url)
  }
}

if ($failed.Count -eq 0) { exit 0 }
exit 1
