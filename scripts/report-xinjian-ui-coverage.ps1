[CmdletBinding(PositionalBinding = $false)]
param(
  [int]$Port = 9342,
  [string]$RouteDiscoveryPath = "",
  [string]$StatePath = "",
  [string]$CuratedMapPath = "",
  [string]$AutoMapPath = "",
  [string]$OverlayMapPath = "",
  [string]$OverlayStatePath = "",
  [string]$IncludeRegex = ".",
  [string]$ExcludeRegex = "^/$|/login|/xtLogin|/sso|/social-login|/404|/401|/redirect|/print|/index/noaccess|/index/ad-no-auth|/setArea",
  [int]$MaxPending = 50,
  [switch]$RefreshRoutes,
  [switch]$Json
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path

if (!$CuratedMapPath) { $CuratedMapPath = Join-Path $root "references\xinjian-ui-map.json" }
if (!$AutoMapPath) { $AutoMapPath = Join-Path $root "references\xinjian-ui-auto-map.json" }
if (!$OverlayMapPath) { $OverlayMapPath = Join-Path $root "references\xinjian-ui-overlay-map.json" }
if (!$StatePath) { $StatePath = Join-Path $root ".ziniao-ops\xinjian-crawl-state.json" }
if (!$OverlayStatePath) { $OverlayStatePath = Join-Path $root ".ziniao-ops\xinjian-overlay-crawl-state.json" }

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

function Read-JsonFile([string]$Path) {
  if (!$Path -or !(Test-Path -LiteralPath $Path)) { return $null }
  try {
    return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
  } catch {
    return $null
  }
}

function ConvertFrom-JsonText($Lines) {
  $text = (($Lines | Out-String).Trim())
  if (!$text) { return $null }
  try { return $text | ConvertFrom-Json } catch { return $null }
}

if (!$RouteDiscoveryPath -or $RefreshRoutes) {
  $routeDir = Join-Path $root ".ziniao-ops\xinjian-route-discovery"
  New-Item -ItemType Directory -Force -Path $routeDir | Out-Null
  $RouteDiscoveryPath = Join-Path $routeDir ("coverage-{0}.json" -f (Get-Date -Format "yyyyMMdd-HHmmss"))
  $raw = @(& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "discover-xinjian-routes.ps1") -Port $Port -OutputPath $RouteDiscoveryPath -Json 2>&1)
  $discovery = ConvertFrom-JsonText $raw
  if (!$discovery -or !$discovery.ok) {
    $payload = [ordered]@{
      ok = $false
      error = "route_discovery_failed"
      raw_output = ($raw | Out-String).Trim()
    }
    if ($Json) { $payload | ConvertTo-Json -Depth 8 } else { Write-Host "Route discovery failed." }
    exit 2
  }
}

$routeMap = Read-JsonFile $RouteDiscoveryPath
if (!$routeMap) {
  $payload = [ordered]@{
    ok = $false
    error = "route_discovery_missing_or_invalid"
    route_discovery_path = $RouteDiscoveryPath
  }
  if ($Json) { $payload | ConvertTo-Json -Depth 8 } else { Write-Host "Route discovery missing or invalid: $RouteDiscoveryPath" }
  exit 2
}

$curated = Read-JsonFile $CuratedMapPath
$auto = Read-JsonFile $AutoMapPath
$overlay = Read-JsonFile $OverlayMapPath
$state = Read-JsonFile $StatePath
$overlayState = Read-JsonFile $OverlayStatePath

$mapped = @{}
foreach ($source in @(
    [pscustomobject]@{ name = "curated"; map = $curated },
    [pscustomobject]@{ name = "auto"; map = $auto }
  )) {
  foreach ($page in @($source.map.pages)) {
    foreach ($needle in @($page.url_contains)) {
      if (!$needle) { continue }
      $key = Get-RouteKey $needle
      if (!$key) { continue }
      if (!$mapped[$key]) {
        $mapped[$key] = [pscustomobject]@{
          source = $source.name
          page_id = $page.id
          page_name = $page.name
        }
      }
    }
  }
}

$attempted = @{}
foreach ($attempt in @($state.attempts)) {
  if (!$attempt.route_key) { continue }
  $attempted[[string]$attempt.route_key] = $attempt
}

$overlayMapped = @{}
$overlayActionCount = 0
foreach ($page in @($overlay.pages)) {
  $overlayActionCount += @($page.actions).Count
  foreach ($needle in @($page.url_contains)) {
    if (!$needle) { continue }
    $key = Get-RouteKey $needle
    if ($key) { $overlayMapped[$key] = $page }
  }
}

$overlayAttempted = @{}
foreach ($attempt in @($overlayState.attempts)) {
  if (!$attempt.route_key) { continue }
  $overlayAttempted[[string]$attempt.route_key] = $attempt
}

$routes = @()
foreach ($route in @($routeMap.routes)) {
  $fullPath = [string]$route.full_path
  if (!$route.navigable_without_params) { continue }
  if (!$fullPath) { continue }
  if ($fullPath -notmatch $IncludeRegex) { continue }
  if ($fullPath -match $ExcludeRegex) { continue }
  $key = Get-RouteKey $fullPath
  if (!$key) { continue }
  $mappedInfo = $mapped[$key]
  $attempt = $attempted[$key]
  $routes += [pscustomobject]@{
    route_key = $key
    path = $fullPath
    name = $route.name
    title = $route.meta_title
    mapped = [bool]$mappedInfo
    map_source = if ($mappedInfo) { $mappedInfo.source } else { $null }
    page_id = if ($mappedInfo) { $mappedInfo.page_id } else { $null }
    attempted = [bool]$attempt
    attempt_status = if ($attempt) { $attempt.status } else { $null }
    controls = if ($attempt) { $attempt.controls } else { $null }
    captured_path = if ($attempt) { $attempt.captured_path } else { $null }
  }
}
$routes = @($routes | Sort-Object path -Unique)

$pending = @($routes | Where-Object { !$_.mapped -and !$_.attempted })
$attemptedUnmapped = @($routes | Where-Object { !$_.mapped -and $_.attempted })
$statusCounts = @($attemptedUnmapped | Group-Object attempt_status | ForEach-Object {
    [ordered]@{ status = if ($_.Name) { $_.Name } else { "unknown" }; count = $_.Count }
  })
$mappedCounts = @($routes | Where-Object { $_.mapped } | Group-Object map_source | ForEach-Object {
    [ordered]@{ source = if ($_.Name) { $_.Name } else { "unknown" }; count = $_.Count }
  })

$knownMappedRoutes = @()
foreach ($entry in $mapped.GetEnumerator()) {
  $key = [string]$entry.Key
  if (!$key) { continue }
  if ($key -notmatch $IncludeRegex) { continue }
  if ($key -match $ExcludeRegex) { continue }
  $info = $entry.Value
  $knownMappedRoutes += [pscustomobject]@{
    route_key = $key
    path = $key
    map_source = $info.source
    page_id = $info.page_id
    page_name = $info.page_name
    overlay_mapped = [bool]$overlayMapped[$key]
    overlay_attempted = [bool]$overlayAttempted[$key]
    overlay_attempt_status = if ($overlayAttempted[$key]) { $overlayAttempted[$key].status } else { $null }
  }
}
$knownMappedRoutes = @($knownMappedRoutes | Sort-Object path -Unique)
$overlayPending = @($knownMappedRoutes | Where-Object { !$_.overlay_mapped -and !$_.overlay_attempted })
$overlayAttemptStatusCounts = @($knownMappedRoutes | Where-Object { $_.overlay_attempted } | Group-Object overlay_attempt_status | ForEach-Object {
    [ordered]@{ status = if ($_.Name) { $_.Name } else { "unknown" }; count = $_.Count }
  })

$payload = [ordered]@{
  ok = $true
  route_discovery_path = [System.IO.Path]::GetFullPath($RouteDiscoveryPath)
  state_path = [System.IO.Path]::GetFullPath($StatePath)
  overlay_state_path = [System.IO.Path]::GetFullPath($OverlayStatePath)
  totals = [ordered]@{
    discovered_routes = @($routeMap.routes).Count
    eligible_routes = $routes.Count
    mapped_routes = @($routes | Where-Object { $_.mapped }).Count
    attempted_unmapped_routes = $attemptedUnmapped.Count
    pending_routes = $pending.Count
    curated_pages = @($curated.pages).Count
    auto_pages = @($auto.pages).Count
    overlay_pages = @($overlay.pages).Count
    overlay_actions = $overlayActionCount
  }
  overlay_totals = [ordered]@{
    known_mapped_pages = $knownMappedRoutes.Count
    overlay_mapped_pages = @($knownMappedRoutes | Where-Object { $_.overlay_mapped }).Count
    overlay_attempted_pages = @($knownMappedRoutes | Where-Object { $_.overlay_attempted }).Count
    overlay_pending_pages = $overlayPending.Count
    overlay_actions = $overlayActionCount
  }
  mapped_counts = @($mappedCounts)
  attempted_unmapped_status_counts = @($statusCounts)
  overlay_attempt_status_counts = @($overlayAttemptStatusCounts)
  pending_routes = @($pending | Select-Object -First $MaxPending)
  attempted_unmapped_routes = @($attemptedUnmapped | Select-Object -First $MaxPending)
  overlay_pending_known_pages = @($overlayPending | Select-Object -First $MaxPending)
}

if ($Json) {
  $payload | ConvertTo-Json -Depth 12
} else {
  Write-Host ("Xinjian UI coverage: {0}/{1} eligible routes mapped, {2} attempted-unmapped, {3} pending." -f $payload.totals.mapped_routes, $payload.totals.eligible_routes, $payload.totals.attempted_unmapped_routes, $payload.totals.pending_routes)
  Write-Host ("Xinjian overlay coverage: {0}/{1} known mapped pages in overlay map, {2} attempted, {3} pending, {4} overlay actions." -f $payload.overlay_totals.overlay_mapped_pages, $payload.overlay_totals.known_mapped_pages, $payload.overlay_totals.overlay_attempted_pages, $payload.overlay_totals.overlay_pending_pages, $payload.overlay_totals.overlay_actions)
  if ($pending.Count -gt 0) {
    Write-Host "Next pending routes:"
    foreach ($route in @($pending | Select-Object -First $MaxPending)) {
      Write-Host ("- {0} {1}" -f $route.path, $route.title)
    }
  }
}
