[CmdletBinding(PositionalBinding = $false)]
param(
  [int]$Port = 9342,
  [string]$Origin = "https://erp.xinjianerp.com",
  [string]$OutputDir = "",
  [int]$MaxPages = 10,
  [string]$IncludeRegex = ".",
  [string]$ExcludeRegex = "^/$|/login|/xtLogin|/sso|/social-login|/404|/401|/redirect|/print|/index/noaccess|/index/ad-no-auth|/setArea",
  [int]$WaitMs = 2500,
  [int]$MaxTriggers = 24,
  [string]$StatePath = "",
  [switch]$OnlyMissing,
  [switch]$RetryAttempted,
  [switch]$IncludeSelects,
  [switch]$IncludeDatePickers,
  [switch]$Json
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path

if (!$OutputDir) {
  $OutputDir = Join-Path $root ".ziniao-ops\xinjian-overlay-captures"
}
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
if (!$StatePath) {
  $StatePath = Join-Path $root ".ziniao-ops\xinjian-overlay-crawl-state.json"
}
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $StatePath) | Out-Null

function ConvertFrom-JsonText($Lines) {
  $text = (($Lines | Out-String).Trim())
  if (!$text) { return $null }
  try { return $text | ConvertFrom-Json } catch { return $null }
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
        return Invoke-RestMethod -Method $method -Uri $endpoint -TimeoutSec 5
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

function Get-SafeSlug([string]$Path) {
  $value = ([string]$Path).Trim("/")
  if (!$value) { $value = "root" }
  $value = $value -replace "[^A-Za-z0-9._-]+", "_"
  if ($value.Length -gt 80) { $value = $value.Substring(0, 80) }
  return $value
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
  return $value
}

function Get-CrawlState {
  if (!(Test-Path -LiteralPath $StatePath)) {
    return [ordered]@{
      version = 1
      updated_at = (Get-Date).ToUniversalTime().ToString("o")
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
    return [ordered]@{
      version = 1
      updated_at = (Get-Date).ToUniversalTime().ToString("o")
      attempts = @()
      read_error = $_.Exception.Message
    }
  }
}

function Save-CrawlState($State) {
  $State.updated_at = (Get-Date).ToUniversalTime().ToString("o")
  $State | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $StatePath -Encoding UTF8
}

function Get-AttemptMap($State) {
  $map = @{}
  foreach ($attempt in @($State.attempts)) {
    if (!$attempt.route_key) { continue }
    $map[[string]$attempt.route_key] = $attempt
  }
  return $map
}

function Set-CrawlAttempt {
  param(
    [object]$State,
    [hashtable]$AttemptMap,
    [string]$Route,
    [string]$Url,
    [string]$Status,
    [object]$Data
  )
  $routeKey = (Get-RouteKey $Route).ToLowerInvariant()
  $item = [ordered]@{
    route_key = $routeKey
    route = $Route
    url = $Url
    status = $Status
    attempted_at = (Get-Date).ToUniversalTime().ToString("o")
  }
  if ($Data) {
    foreach ($prop in $Data.PSObject.Properties) {
      if ($prop.Name -notin @("route_key", "route", "url", "status", "attempted_at")) {
        $item[$prop.Name] = $prop.Value
      }
    }
  }
  $AttemptMap[$routeKey] = [pscustomobject]$item
  $State.attempts = @($AttemptMap.Values | Sort-Object route_key)
}

function Get-MapPages {
  $items = @()
  foreach ($entry in @(
      @{ path = (Join-Path $root "references\xinjian-ui-map.json"); source = "curated" },
      @{ path = (Join-Path $root "references\xinjian-ui-auto-map.json"); source = "auto" }
    )) {
    if (!(Test-Path -LiteralPath $entry.path)) { continue }
    try {
      $map = Get-Content -LiteralPath $entry.path -Raw -Encoding UTF8 | ConvertFrom-Json
      foreach ($page in @($map.pages)) {
        $route = ""
        foreach ($candidate in @($page.url_contains)) {
          if ($candidate) {
            $route = Get-RouteKey $candidate
            break
          }
        }
        if (!$route) { continue }
        $items += [pscustomobject]@{
          route_key = $route.ToLowerInvariant()
          route = $route
          url = ([uri]::new([uri]$Origin, $route)).AbsoluteUri
          name = $page.name
          page_id = $page.id
          source = $entry.source
        }
      }
    } catch {
    }
  }
  $seen = @{}
  foreach ($item in @($items | Sort-Object source, route_key)) {
    if ($seen[$item.route_key]) { continue }
    $seen[$item.route_key] = $item
  }
  return @($seen.Values | Sort-Object route_key)
}

function Get-ExistingOverlayPaths {
  $paths = @{}
  $overlayMapPath = Join-Path $root "references\xinjian-ui-overlay-map.json"
  if (!(Test-Path -LiteralPath $overlayMapPath)) { return $paths }
  try {
    $map = Get-Content -LiteralPath $overlayMapPath -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($page in @($map.pages)) {
      foreach ($needle in @($page.url_contains)) {
        if ($needle) { $paths[(Get-RouteKey $needle).ToLowerInvariant()] = $true }
      }
    }
  } catch {
  }
  return $paths
}

if (!(Test-CdpPort -CdpPort $Port)) {
  $payload = [ordered]@{
    ok = $false
    error = "cdp_port_not_reachable"
    port = $Port
  }
  if ($Json) { $payload | ConvertTo-Json -Depth 8 } else { Write-Host "CDP port not reachable: $Port" }
  exit 2
}

$state = Get-CrawlState
$attemptMap = Get-AttemptMap -State $state
$existingOverlayPaths = if ($OnlyMissing) { Get-ExistingOverlayPaths } else { @{} }
$routes = @()
foreach ($page in @(Get-MapPages)) {
  $route = [string]$page.route
  $key = ([string]$page.route_key).ToLowerInvariant()
  if (!$route) { continue }
  if ($route -notmatch $IncludeRegex) { continue }
  if ($route -match $ExcludeRegex) { continue }
  if ($OnlyMissing -and $existingOverlayPaths[$key]) { continue }
  if (!$RetryAttempted -and $attemptMap[$key]) { continue }
  $routes += $page
}

if ($MaxPages -gt 0) {
  $routes = @($routes | Select-Object -First $MaxPages)
}

$captures = @()
foreach ($route in $routes) {
  $path = [string]$route.route
  $url = [string]$route.url
  $slug = Get-SafeSlug -Path $path
  $capturePath = Join-Path $OutputDir ("{0}-{1}.json" -f (Get-Date -Format "yyyyMMdd-HHmmss"), $slug)

  $openedPage = Open-CdpUrl -CdpPort $Port -TargetUrl $url
  if (!$openedPage) {
    Set-CrawlAttempt -State $state -AttemptMap $attemptMap -Route $path -Url $url -Status "open_failed" -Data ([pscustomobject]@{
        error = "open_cdp_url_failed"
        page_id = $route.page_id
        source = $route.source
      })
    Save-CrawlState -State $state
    $captures += [pscustomobject]@{
      ok = $false
      route = $path
      url = $url
      page_id = $route.page_id
      error = "open_cdp_url_failed"
    }
    continue
  }

  if ($WaitMs -gt 0) { Start-Sleep -Milliseconds $WaitMs }
  $captureRaw = @()
  try {
    $argsList = @(
      "-NoProfile", "-ExecutionPolicy", "Bypass",
      "-File", (Join-Path $PSScriptRoot "capture-xinjian-overlays.ps1"),
      "-Port", [string]$Port,
      "-Url", $url,
      "-OutputPath", $capturePath,
      "-MaxTriggers", [string]$MaxTriggers,
      "-Json"
    )
    if ($IncludeSelects) { $argsList += "-IncludeSelects" }
    if ($IncludeDatePickers) { $argsList += "-IncludeDatePickers" }
    $captureRaw = @(& powershell @argsList 2>&1)
  } catch {
    $captureRaw = @($_.Exception.Message)
  }
  $capture = ConvertFrom-JsonText $captureRaw
  if ($capture -and $capture.ok) {
    $routeKey = Get-RouteKey $path
    $capturedKey = Get-RouteKey ([string]$capture.page.path)
    $status = if ($capturedKey -and $capturedKey.ToLowerInvariant() -ne $routeKey.ToLowerInvariant()) {
      "redirected"
    } elseif ([int]$capture.counts.triggers -le 0) {
      "no_overlay_triggers"
    } elseif ([int]$capture.counts.items -le 0) {
      "triggers_without_items"
    } else {
      "captured"
    }
    Set-CrawlAttempt -State $state -AttemptMap $attemptMap -Route $path -Url $url -Status $status -Data ([pscustomobject]@{
        title = $capture.page.title
        captured_path = $capture.page.path
        triggers = $capture.counts.triggers
        overlays_with_items = $capture.counts.overlays_with_items
        items = $capture.counts.items
        filtered_items = $capture.counts.filtered_items
        output_path = $capture.output_path
        page_id = $route.page_id
        source = $route.source
      })
    Save-CrawlState -State $state
    $captures += [pscustomobject]@{
      ok = $true
      route = $path
      url = $url
      title = $capture.page.title
      captured_path = $capture.page.path
      triggers = $capture.counts.triggers
      overlays_with_items = $capture.counts.overlays_with_items
      items = $capture.counts.items
      filtered_items = $capture.counts.filtered_items
      status = $status
      output_path = $capture.output_path
      page_id = $route.page_id
      source = $route.source
    }
  } else {
    Set-CrawlAttempt -State $state -AttemptMap $attemptMap -Route $path -Url $url -Status "capture_failed" -Data ([pscustomobject]@{
        error = "capture_failed"
        raw_output = ($captureRaw | Out-String).Trim()
        page_id = $route.page_id
        source = $route.source
      })
    Save-CrawlState -State $state
    $captures += [pscustomobject]@{
      ok = $false
      route = $path
      url = $url
      error = "capture_failed"
      raw_output = ($captureRaw | Out-String).Trim()
      page_id = $route.page_id
      source = $route.source
    }
  }
  Close-CdpPage -CdpPort $Port -TargetId ([string]$openedPage.id)
}

$payload = [ordered]@{
  ok = (@($captures | Where-Object { !$_.ok }).Count -eq 0)
  port = $Port
  output_dir = (Resolve-Path -LiteralPath $OutputDir).Path
  state_path = [System.IO.Path]::GetFullPath($StatePath)
  selected_routes = $routes.Count
  captures = @($captures)
}

if ($Json) {
  $payload | ConvertTo-Json -Depth 12
} else {
  Write-Host ("Captured overlays on {0}/{1} Xinjian pages." -f (@($captures | Where-Object { $_.ok }).Count), $captures.Count)
  foreach ($item in $captures) {
    if ($item.ok) {
      Write-Host ("OK {0} -> {1} triggers, {2} items ({3})" -f $item.route, $item.triggers, $item.items, $item.status)
    } else {
      Write-Host ("FAILED {0}: {1}" -f $item.route, $item.error)
    }
  }
}

if (!$payload.ok) { exit 1 }
