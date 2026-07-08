[CmdletBinding(PositionalBinding = $false)]
param(
  [Parameter(Mandatory = $true)]
  [string]$Intent,
  [string]$Url = "",
  [string]$MapPath = "",
  [switch]$Json
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
if (!$MapPath) {
  $MapPath = Join-Path $root "references\xinjian-ui-map.json"
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

function Get-RoutePath([string]$InputUrl) {
  if (!$InputUrl) { return "" }
  try {
    $uri = [uri]$InputUrl
    return $uri.AbsolutePath
  } catch {
    return $InputUrl
  }
}

function Get-ActionScore($Action, [string]$Query) {
  $score = 0
  $fields = @()
  foreach ($name in @("name", "purpose", "type", "safety")) {
    if ($Action.PSObject.Properties.Match($name).Count -gt 0 -and $Action.$name) {
      $fields += [string]$Action.$name
    }
  }
  foreach ($alias in @($Action.aliases)) {
    if ($alias) { $fields += [string]$alias }
  }
  foreach ($field in $fields) {
    $norm = Normalize-Text $field
    if (!$norm) { continue }
    if ($Query -eq $norm) { $score += 100 }
    elseif ($Query.Contains($norm) -or $norm.Contains($Query)) { $score += 35 }
    else {
      foreach ($part in @([regex]::Split($Query, "[\s,/]+") | Where-Object { $_ })) {
        if ($norm.Contains($part)) { $score += 8 }
      }
    }
  }
  return $score
}

$map = Get-Content -LiteralPath $MapPath -Raw -Encoding UTF8 | ConvertFrom-Json
$query = Normalize-Text $Intent
$route = Get-RoutePath $Url

$matchedPages = @()
foreach ($page in @($map.pages)) {
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
  $matchedPages = @($map.pages | ForEach-Object { [pscustomobject]@{ page = $_; score = 0 } })
}

$candidates = @()
foreach ($action in @($map.global_actions)) {
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

$candidates = @($candidates | Sort-Object score -Descending | Select-Object -First 10)
$payload = [ordered]@{
  ok = ($candidates.Count -gt 0)
  intent = $Intent
  url = $Url
  route = $route
  map_version = $map.version
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
