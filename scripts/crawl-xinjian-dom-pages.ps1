[CmdletBinding(PositionalBinding = $false)]
param(
  [int]$Port = 9342,
  [string]$Origin = "https://erp.xinjianerp.com",
  [string]$RouteDiscoveryPath = "",
  [string]$OutputDir = "",
  [int]$MaxPages = 25,
  [string]$IncludeRegex = ".",
  [string]$ExcludeRegex = "^/$|/login|/xtLogin|/sso|/social-login|/404|/401|/redirect|/print|/index/noaccess|/index/ad-no-auth|/setArea",
  [int]$WaitMs = 2500,
  [string]$StatePath = "",
  [switch]$OnlyUnmapped,
  [switch]$RetryAttempted,
  [switch]$Json
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path

if (!$OutputDir) {
  $OutputDir = Join-Path $root ".ziniao-ops\xinjian-dom-captures"
}
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
if (!$StatePath) {
  $StatePath = Join-Path $root ".ziniao-ops\xinjian-crawl-state.json"
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

function Get-MappedPaths {
  $paths = @{}
  foreach ($mapPath in @(
      (Join-Path $root "references\xinjian-ui-map.json"),
      (Join-Path $root "references\xinjian-ui-auto-map.json")
    )) {
    if (!(Test-Path -LiteralPath $mapPath)) { continue }
    try {
      $map = Get-Content -LiteralPath $mapPath -Raw -Encoding UTF8 | ConvertFrom-Json
      foreach ($page in @($map.pages)) {
        foreach ($needle in @($page.url_contains)) {
          if ($needle) { $paths[(Get-RouteKey $needle).ToLowerInvariant()] = $true }
        }
      }
    } catch {
    }
  }
  Write-Output -NoEnumerate $paths
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

if (!$RouteDiscoveryPath) {
  $routeDir = Join-Path $root ".ziniao-ops\xinjian-route-discovery"
  New-Item -ItemType Directory -Force -Path $routeDir | Out-Null
  $RouteDiscoveryPath = Join-Path $routeDir ("crawl-{0}.json" -f (Get-Date -Format "yyyyMMdd-HHmmss"))
  $discoverRaw = @()
  try {
    $discoverRaw = @(& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "discover-xinjian-routes.ps1") -Port $Port -OutputPath $RouteDiscoveryPath -Json 2>&1)
  } catch {
    $discoverRaw = @($_.Exception.Message)
  }
  $discover = ConvertFrom-JsonText $discoverRaw
  if (!$discover -or !$discover.ok) {
    $payload = [ordered]@{
      ok = $false
      error = "route_discovery_failed"
      raw_output = ($discoverRaw | Out-String).Trim()
    }
    if ($Json) { $payload | ConvertTo-Json -Depth 8 } else { Write-Host "Route discovery failed." }
    exit 2
  }
}

$routeMap = Get-Content -LiteralPath $RouteDiscoveryPath -Raw -Encoding UTF8 | ConvertFrom-Json
$mappedPaths = if ($OnlyUnmapped) { Get-MappedPaths } else { $null }
if ($OnlyUnmapped -and $null -eq $mappedPaths) {
  $mappedPaths = @{}
}
$crawlState = Get-CrawlState
$attemptMap = Get-AttemptMap -State $crawlState
$routes = @()
foreach ($route in @($routeMap.routes)) {
  $fullPath = [string]$route.full_path
  if (!$route.navigable_without_params) { continue }
  if (!$fullPath) { continue }
  if ($fullPath -notmatch $IncludeRegex) { continue }
  if ($fullPath -match $ExcludeRegex) { continue }
  if ($OnlyUnmapped) {
    $key = (Get-RouteKey $fullPath).ToLowerInvariant()
    if ($mappedPaths -and $mappedPaths[$key]) { continue }
    if (!$RetryAttempted -and $attemptMap -and $attemptMap[$key]) { continue }
  }
  $routes += $route
}
$routes = @($routes | Sort-Object full_path -Unique)

if ($MaxPages -gt 0) {
  $routes = @($routes | Select-Object -First $MaxPages)
}

$captures = @()
foreach ($route in $routes) {
  $path = [string]$route.full_path
  $url = ([uri]::new([uri]$Origin, $path)).AbsoluteUri
  $slug = Get-SafeSlug -Path $path
  $capturePath = Join-Path $OutputDir ("{0}-{1}.json" -f (Get-Date -Format "yyyyMMdd-HHmmss"), $slug)

  $openedPage = Open-CdpUrl -CdpPort $Port -TargetUrl $url
  if (!$openedPage) {
    Set-CrawlAttempt -State $crawlState -AttemptMap $attemptMap -Route $path -Url $url -Status "open_failed" -Data ([pscustomobject]@{
        error = "open_cdp_url_failed"
      })
    Save-CrawlState -State $crawlState
    $captures += [pscustomobject]@{
      ok = $false
      route = $path
      url = $url
      error = "open_cdp_url_failed"
    }
    continue
  }

  if ($WaitMs -gt 0) { Start-Sleep -Milliseconds $WaitMs }
  $captureRaw = @()
  try {
    $captureRaw = @(& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "capture-xinjian-dom-map.ps1") -Port $Port -Url $url -OutputPath $capturePath -Json 2>&1)
  } catch {
    $captureRaw = @($_.Exception.Message)
  }
  $capture = ConvertFrom-JsonText $captureRaw
  if ($capture -and $capture.ok) {
    $routeKey = Get-RouteKey $path
    $capturedKey = Get-RouteKey ([string]$capture.page.path)
    $status = if ([int]$capture.counts.controls -le 0) {
      "empty"
    } elseif ($capturedKey -eq "/index/noaccess") {
      "noaccess"
    } elseif ($capturedKey -and $capturedKey.ToLowerInvariant() -ne $routeKey.ToLowerInvariant()) {
      "redirected"
    } else {
      "captured"
    }
    Set-CrawlAttempt -State $crawlState -AttemptMap $attemptMap -Route $path -Url $url -Status $status -Data ([pscustomobject]@{
        title = $capture.page.title
        captured_path = $capture.page.path
        controls = $capture.counts.controls
        buttons = $capture.counts.buttons
        inputs = $capture.counts.inputs
        tabs = $capture.counts.tabs
        menus = $capture.counts.menus
        output_path = $capture.output_path
      })
    Save-CrawlState -State $crawlState
    $captures += [pscustomobject]@{
      ok = $true
      route = $path
      url = $url
      title = $capture.page.title
      captured_path = $capture.page.path
      controls = $capture.counts.controls
      buttons = $capture.counts.buttons
      inputs = $capture.counts.inputs
      tabs = $capture.counts.tabs
      menus = $capture.counts.menus
      status = $status
      output_path = $capture.output_path
    }
  } else {
    Set-CrawlAttempt -State $crawlState -AttemptMap $attemptMap -Route $path -Url $url -Status "capture_failed" -Data ([pscustomobject]@{
        error = "capture_failed"
        raw_output = ($captureRaw | Out-String).Trim()
      })
    Save-CrawlState -State $crawlState
    $captures += [pscustomobject]@{
      ok = $false
      route = $path
      url = $url
      error = "capture_failed"
      raw_output = ($captureRaw | Out-String).Trim()
    }
  }
  Close-CdpPage -CdpPort $Port -TargetId ([string]$openedPage.id)
}

$payload = [ordered]@{
  ok = (@($captures | Where-Object { !$_.ok }).Count -eq 0)
  port = $Port
  route_discovery_path = (Resolve-Path -LiteralPath $RouteDiscoveryPath).Path
  output_dir = (Resolve-Path -LiteralPath $OutputDir).Path
  state_path = [System.IO.Path]::GetFullPath($StatePath)
  selected_routes = $routes.Count
  captures = @($captures)
}

if ($Json) {
  $payload | ConvertTo-Json -Depth 12
} else {
  Write-Host ("Captured {0}/{1} Xinjian pages." -f (@($captures | Where-Object { $_.ok }).Count), $captures.Count)
  foreach ($item in $captures) {
    if ($item.ok) {
      Write-Host ("OK {0} -> {1} controls ({2})" -f $item.route, $item.controls, $item.title)
    } else {
      Write-Host ("FAILED {0}: {1}" -f $item.route, $item.error)
    }
  }
}

if (!$payload.ok) { exit 1 }
