[CmdletBinding(PositionalBinding = $false)]
param(
  [Parameter(Mandatory = $true)]
  [string]$Intent,
  [string]$Url = "",
  [string]$MapPath = "",
  [string]$AutoMapPath = "",
  [string]$OverlayMapPath = "",
  [switch]$NoAutoMap,
  [switch]$NoOverlayMap,
  [switch]$Json
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
if (!$MapPath) {
  $MapPath = Join-Path $root "references\xinjian-ui-map.json"
}
if (!$AutoMapPath) {
  $AutoMapPath = Join-Path $root "references\xinjian-ui-auto-map.json"
}
if (!$OverlayMapPath) {
  $OverlayMapPath = Join-Path $root "references\xinjian-ui-overlay-map.json"
}
if (!(Test-Path -LiteralPath $MapPath)) {
  $payload = [ordered]@{
    ok = $false
    error = "xinjian_ui_map_missing"
    map_path = $MapPath
  }
  if ($Json) { $payload | ConvertTo-Json -Depth 6 } else { Write-Host "Xinjian UI map missing: $MapPath" }
  exit 2
}

function Normalize-Text([string]$Text) {
  return ([string]$Text).ToLowerInvariant().Trim()
}

function Compact-Text([string]$Text) {
  return (Normalize-Text $Text) -replace "\s+", ""
}

function New-UnicodeText([int[]]$Codepoints) {
  return -join ($Codepoints | ForEach-Object { [char]$_ })
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

function Get-ActionScore($Action, [string]$Query) {
  $score = 0
  $queryCompact = Compact-Text $Query
  $commandWords = @(
    (New-UnicodeText @(0x641C, 0x7D22)),
    (New-UnicodeText @(0x67E5, 0x8BE2)),
    (New-UnicodeText @(0x91CD, 0x7F6E)),
    (New-UnicodeText @(0x65B0, 0x589E)),
    (New-UnicodeText @(0x6DFB, 0x52A0)),
    (New-UnicodeText @(0x4FDD, 0x5B58)),
    (New-UnicodeText @(0x63D0, 0x4EA4)),
    (New-UnicodeText @(0x5BFC, 0x51FA)),
    (New-UnicodeText @(0x4E0B, 0x8F7D)),
    (New-UnicodeText @(0x5220, 0x9664)),
    (New-UnicodeText @(0x7F16, 0x8F91)),
    (New-UnicodeText @(0x4FEE, 0x6539)),
    (New-UnicodeText @(0x5E94, 0x7528)),
    (New-UnicodeText @(0x6279, 0x91CF)),
    (New-UnicodeText @(0x6807, 0x8BB0))
  )
  $fields = @()
  foreach ($name in @("name", "purpose", "type", "safety")) {
    if ($Action.PSObject.Properties.Match($name).Count -gt 0 -and $Action.$name) {
      $fields += [string]$Action.$name
    }
  }
  foreach ($alias in @($Action.aliases)) {
    if ($alias) { $fields += [string]$alias }
  }
  $seenFields = @{}
  foreach ($field in $fields) {
    $norm = Normalize-Text $field
    $normCompact = Compact-Text $norm
    if (!$norm) { continue }
    if ($seenFields[$normCompact]) { continue }
    $seenFields[$normCompact] = $true
    foreach ($word in $commandWords) {
      if ($queryCompact.Contains($word) -and $normCompact.Contains($word)) {
        $score += 45
        break
      }
    }
    if ($Query -eq $norm) { $score += 100 }
    elseif ($queryCompact -and $queryCompact -eq $normCompact) { $score += 95 }
    elseif ($Query.Contains($norm) -or $norm.Contains($Query) -or ($queryCompact -and ($queryCompact.Contains($normCompact) -or $normCompact.Contains($queryCompact)))) { $score += 35 }
    else {
      foreach ($part in @([regex]::Split($Query, "[\s,/]+") | Where-Object { $_ })) {
        if ($norm.Contains($part)) { $score += 8 }
      }
    }
  }
  $hasReadIntentWord = $false
  foreach ($word in @($commandWords[0], $commandWords[1], $commandWords[2])) {
    if ($queryCompact.Contains($word)) {
      $hasReadIntentWord = $true
      break
    }
  }
  if ($Action.PSObject.Properties.Match("safety").Count -gt 0 -and $Action.safety -eq "read_filter" -and $hasReadIntentWord) {
    $score += 15
  }
  return $score
}

$map = Get-Content -LiteralPath $MapPath -Raw -Encoding UTF8 | ConvertFrom-Json
$autoMap = $null
if (!$NoAutoMap -and (Test-Path -LiteralPath $AutoMapPath)) {
  try {
    $autoMap = Get-Content -LiteralPath $AutoMapPath -Raw -Encoding UTF8 | ConvertFrom-Json
  } catch {
    $autoMap = $null
  }
}
$overlayMap = $null
if (!$NoOverlayMap -and (Test-Path -LiteralPath $OverlayMapPath)) {
  try {
    $overlayMap = Get-Content -LiteralPath $OverlayMapPath -Raw -Encoding UTF8 | ConvertFrom-Json
  } catch {
    $overlayMap = $null
  }
}
$allPages = @($map.pages)
$pageKeys = @{}
foreach ($page in @($allPages)) {
  if ($page.id) { $pageKeys[[string]$page.id] = $true }
  foreach ($needle in @($page.url_contains)) {
    if ($needle) { $pageKeys[(Get-RouteKey $needle)] = $true }
  }
}
if ($autoMap -and $autoMap.pages) {
  foreach ($page in @($autoMap.pages)) {
    $duplicate = $false
    if ($page.id -and $pageKeys.ContainsKey([string]$page.id)) { $duplicate = $true }
    foreach ($needle in @($page.url_contains)) {
      if ($needle -and $pageKeys.ContainsKey((Get-RouteKey $needle))) { $duplicate = $true }
    }
    if (!$duplicate) {
      $allPages += $page
      if ($page.id) { $pageKeys[[string]$page.id] = $true }
      foreach ($needle in @($page.url_contains)) {
        if ($needle) { $pageKeys[(Get-RouteKey $needle)] = $true }
      }
    }
  }
}
if ($overlayMap -and $overlayMap.pages) {
  foreach ($page in @($overlayMap.pages)) {
    $allPages += $page
  }
}
$allGlobalActions = @($map.global_actions)
if ($autoMap -and $autoMap.global_actions) {
  $allGlobalActions += @($autoMap.global_actions)
}
if ($overlayMap -and $overlayMap.global_actions) {
  $allGlobalActions += @($overlayMap.global_actions)
}
$query = Normalize-Text $Intent
$route = Get-RoutePath $Url

$matchedPages = @()
foreach ($page in @($allPages)) {
  $pageScore = 0
  if ($route -and $page.route_pattern -and $route -match $page.route_pattern) { $pageScore += 100 }
  if ($Url -and $page.url_contains) {
    foreach ($needle in @($page.url_contains)) {
      if ($Url -like "*$needle*") { $pageScore += 50 }
    }
  }
  if ($query -and ((Normalize-Text $page.name).Contains($query) -or $query.Contains((Normalize-Text $page.name)))) {
    $pageScore += 30
  }
  if ($pageScore -gt 0) {
    $matchedPages += [pscustomobject]@{ page = $page; score = $pageScore }
  }
}
if ($matchedPages.Count -eq 0 -and !$Url) {
  $matchedPages = @($allPages | ForEach-Object { [pscustomobject]@{ page = $_; score = 0 } })
}

$candidates = @()
foreach ($action in @($allGlobalActions)) {
  $score = Get-ActionScore -Action $action -Query $query
  if ($score -gt 0) {
    $candidates += [pscustomobject]@{
      score = $score
      match_scope = "global"
      page_id = $null
      action = $action
    }
  }
}
foreach ($matched in @($matchedPages)) {
  foreach ($action in @($matched.page.actions)) {
    $actionScore = Get-ActionScore -Action $action -Query $query
    if ($actionScore -gt 0) {
      $score = $actionScore + [int]($matched.score / 5)
      $candidates += [pscustomobject]@{
        score = $score
        match_scope = "page"
        page_id = $matched.page.id
        page_name = $matched.page.name
        action = $action
      }
    }
  }
}

$candidates = @($candidates |
  ForEach-Object {
    $action = $_.action
    $rank = 0
    $genericChooseText = New-UnicodeText @(0x8BF7, 0x9009, 0x62E9)
    $triggerText = ""
    if ($action.PSObject.Properties.Match("locator").Count -gt 0 -and $action.locator -and $action.locator.PSObject.Properties.Match("trigger_text").Count -gt 0) {
      $triggerText = [string]$action.locator.trigger_text
    }
    if ($action.type -eq "navigation") { $rank -= 20 }
    if ($action.type -eq "button" -or $action.type -eq "batch_action") { $rank += 10 }
    if ($action.type -eq "overlay_item") { $rank += 12 }
    if ($action.type -eq "overlay_trigger") { $rank -= 5 }
    if ($action.safety -eq "read_filter") { $rank += 8 }
    if ([string]$action.safety -like "confirmation_required*") { $rank += 6 }
    if ($triggerText -eq $genericChooseText) { $rank -= 8 }
    elseif ($triggerText) { $rank += 4 }
    $_ | Add-Member -NotePropertyName rank -NotePropertyValue $rank -Force
    $_
  } |
  Sort-Object @{ Expression = "score"; Descending = $true }, @{ Expression = "rank"; Descending = $true } |
  Select-Object -First 10)
$payload = [ordered]@{
  ok = ($candidates.Count -gt 0)
  intent = $Intent
  url = $Url
  route = $route
  map_version = $map.version
  auto_map_version = if ($autoMap) { $autoMap.version } else { $null }
  overlay_map_version = if ($overlayMap) { $overlayMap.version } else { $null }
  map_pages_total = $allPages.Count
  matched_pages = @($matchedPages | Sort-Object score -Descending | Select-Object -First 5 | ForEach-Object {
      [ordered]@{ id = $_.page.id; name = $_.page.name; score = $_.score }
    })
  matches = @($candidates)
  next_action = if ($candidates.Count -gt 0) { "use_best_match_or_capture_current_page" } else { "capture_current_page_then_update_xinjian_ui_map" }
}

if ($Json) {
  $payload | ConvertTo-Json -Depth 14
} else {
  if ($candidates.Count -eq 0) {
    Write-Host "No mapped Xinjian action matched. Capture the current page and update references\xinjian-ui-map.json."
  } else {
    foreach ($match in $candidates) {
      Write-Host ("[{0}] {1} / {2} -> {3}" -f $match.score, $match.page_name, $match.action.name, $match.action.purpose)
    }
  }
}
