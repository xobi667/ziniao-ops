[CmdletBinding(PositionalBinding = $false)]
param(
  [string]$Url = "",
  [int[]]$Port = @(),
  [string]$Intent = "",
  [string]$CatalogPath = "",
  [switch]$NoAutoDetectUrl,
  [switch]$SafeOnly,
  [int]$Limit = 0,
  [switch]$Json
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
if (!$CatalogPath) {
  $CatalogPath = Join-Path $root "references\xinjian-ui-action-catalog.json"
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

function Get-PortArgumentList {
  param([int[]]$Ports)
  $items = @($Ports | Where-Object { $_ -gt 0 } | Sort-Object -Unique)
  $args = @()
  foreach ($item in $items) {
    $args += @("-Port", [string]$item)
  }
  return $args
}

function Get-RoutePath([string]$InputUrl) {
  if (!$InputUrl) { return "" }
  try {
    $uri = [uri]$InputUrl
    return $uri.AbsolutePath
  } catch {
    return $InputUrl
  }
}

function Get-RouteKey([string]$InputPath) {
  if (!$InputPath) { return "" }
  $value = [string]$InputPath
  if ($value -match "^[A-Za-z][A-Za-z0-9+.-]*://") {
    try {
      $uri = [uri]$value
      $value = $uri.AbsolutePath
    } catch {
    }
  }
  if (!$value) { return "" }
  if (!$value.StartsWith("/")) { $value = "/" + $value }
  $value = $value -replace "/+", "/"
  if ($value.Length -gt 1) { $value = $value.TrimEnd("/") }
  return $value.ToLowerInvariant()
}

function Get-PageMatchScore($Page, [string]$InputUrl) {
  if (!$InputUrl) { return 0 }
  $route = Get-RoutePath $InputUrl
  $routeKey = Get-RouteKey $route
  $score = 0
  if ($Page.route -and (Get-RouteKey ([string]$Page.route)) -eq $routeKey) { $score += 120 }
  if ($route -and $Page.route_pattern -and $route -match $Page.route_pattern) { $score += 110 }
  foreach ($needle in @($Page.url_contains)) {
    if (!$needle) { continue }
    if ($InputUrl -like "*$needle*") { $score += 60 }
    if ((Get-RouteKey ([string]$needle)) -eq $routeKey) { $score += 60 }
  }
  return $score
}

function New-ActionSummary($Action) {
  [ordered]@{
    id = [string]$Action.id
    name = [string]$Action.name
    type = [string]$Action.type
    safety_mode = [string]$Action.safety_mode
    confirmation_required = [bool]$Action.confirmation_required
    locator_strategy = [string]$Action.locator_strategy
    context = [string]$Action.context
    purpose = [string]$Action.purpose
    source_map = [string]$Action.source_map
    aliases = @($Action.aliases)
    locator = $Action.locator
  }
}

if (!(Test-Path -LiteralPath $CatalogPath)) {
  $payload = [ordered]@{
    ok = $false
    error = "xinjian_action_catalog_missing"
    catalog_path = $CatalogPath
    next_action = "run_generate_xinjian_ui_action_catalog"
  }
  if ($Json) { $payload | ConvertTo-Json -Depth 8 } else { Write-Host "Xinjian action catalog missing: $CatalogPath" }
  exit 2
}

$requestedUrl = $Url
$urlResolution = $null
if (!$Url -and !$NoAutoDetectUrl) {
  $resolver = Join-Path $PSScriptRoot "resolve-xinjian-current-url.ps1"
  if (Test-Path -LiteralPath $resolver) {
    $resolveArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $resolver)
    $resolveArgs += Get-PortArgumentList -Ports $Port
    $resolveArgs += "-Json"
    if ($Intent) { $resolveArgs += @("-Intent", $Intent) }
    $rawResolution = @(& powershell @resolveArgs 2>&1)
    $urlResolution = ConvertFrom-JsonText $rawResolution
    if ($urlResolution -and $urlResolution.ok -and $urlResolution.url) {
      $Url = [string]$urlResolution.url
    }
  }
}

if (!$Url) {
  $payload = [ordered]@{
    ok = $false
    mode = "current_page_unresolved"
    requested_url = $requestedUrl
    url_resolution = $urlResolution
    next_action = "focus_the_target_xinjian_window_or_pass_url"
  }
  if ($Json) { $payload | ConvertTo-Json -Depth 14 } else { Write-Host "No current Xinjian page URL was resolved. Pass -Url or focus the target Xinjian window." }
  exit 1
}

$catalog = Get-Content -LiteralPath $CatalogPath -Raw -Encoding UTF8 | ConvertFrom-Json
$matches = @($catalog.pages | ForEach-Object {
    $score = Get-PageMatchScore -Page $_ -InputUrl $Url
    if ($score -gt 0) {
      [pscustomobject]@{ page = $_; score = $score }
    }
  } | Sort-Object score -Descending)

if ($matches.Count -eq 0) {
  $payload = [ordered]@{
    ok = $false
    mode = "page_not_in_catalog"
    url = $Url
    requested_url = $requestedUrl
    url_resolution = $urlResolution
    catalog_version = $catalog.version
    catalog_totals = $catalog.totals
    next_action = "capture_current_page_then_regenerate_xinjian_action_catalog"
  }
  if ($Json) { $payload | ConvertTo-Json -Depth 12 } else { Write-Host "Current Xinjian page is not in the action catalog: $Url" }
  exit 1
}

$selected = $matches[0].page
$allActions = @($selected.actions)
$listedActions = $allActions
if ($SafeOnly) {
  $listedActions = @($listedActions | Where-Object { $_.safety_mode -eq "safe_execute_allowed" })
}
if ($Limit -gt 0) {
  $listedActions = @($listedActions | Select-Object -First $Limit)
}

$actionSummaries = @($listedActions | ForEach-Object { New-ActionSummary $_ })
$counts = [ordered]@{
  total = $allActions.Count
  listed = $actionSummaries.Count
  safe_execute_allowed = @($allActions | Where-Object { $_.safety_mode -eq "safe_execute_allowed" }).Count
  confirmation_required_write = @($allActions | Where-Object { $_.safety_mode -eq "confirmation_required_write" }).Count
  confirmation_required_export = @($allActions | Where-Object { $_.safety_mode -eq "confirmation_required_export" }).Count
  row_context_required = @($allActions | Where-Object { $_.locator_strategy -like "row_context_required*" }).Count
}

$payload = [ordered]@{
  ok = $true
  mode = "page_actions"
  url = $Url
  requested_url = $requestedUrl
  url_resolution = $urlResolution
  catalog_version = $catalog.version
  catalog_totals = $catalog.totals
  page = [ordered]@{
    id = [string]$selected.id
    name = [string]$selected.name
    module = [string]$selected.module
    route = [string]$selected.route
    sources = @($selected.sources)
    match_score = [int]$matches[0].score
  }
  counts = $counts
  actions = $actionSummaries
  next_action = "use_invoke_xinjian_ui_action_with_intent_for_safe_dry_run_or_execution"
}

if ($Json) {
  $payload | ConvertTo-Json -Depth 18
} else {
  Write-Host ("{0} / {1} ({2})" -f $payload.page.module, $payload.page.name, $payload.page.route)
  Write-Host ("Actions: total={0}, safe={1}, write={2}, export={3}, row-context={4}" -f $counts.total, $counts.safe_execute_allowed, $counts.confirmation_required_write, $counts.confirmation_required_export, $counts.row_context_required)
  $rows = @($actionSummaries | ForEach-Object {
      [pscustomobject]@{
        name = $_.name
        type = $_.type
        safety = $_.safety_mode
        locator = $_.locator_strategy
        purpose = $_.purpose
      }
    })
  $rows | Format-Table -AutoSize | Out-String | Write-Output
}
