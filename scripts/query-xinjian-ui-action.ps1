[CmdletBinding(PositionalBinding = $false)]
param(
  [Parameter(Mandatory = $true)]
  [string]$Intent,
  [string]$Url = "",
  [string]$MapPath = "",
  [string]$AutoMapPath = "",
  [string]$OverlayMapPath = "",
  [string]$DialogMapPath = "",
  [string]$RowActionMapPath = "",
  [string]$CatalogPath = "",
  [switch]$NoAutoMap,
  [switch]$NoOverlayMap,
  [switch]$NoDialogMap,
  [switch]$NoRowActionMap,
  [switch]$NoCatalog,
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
if (!$DialogMapPath) {
  $DialogMapPath = Join-Path $root "references\xinjian-ui-dialog-map.json"
}
if (!$RowActionMapPath) {
  $RowActionMapPath = Join-Path $root "references\xinjian-ui-row-action-map.json"
}
if (!$CatalogPath) {
  $CatalogPath = Join-Path $root "references\xinjian-ui-action-catalog.json"
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

function Get-DateQuickIntentCanonical([string]$QueryCompact) {
  if (!$QueryCompact) { return "" }
  $today = New-UnicodeText @(0x4ECA, 0x5929)
  $yesterday = New-UnicodeText @(0x6628, 0x5929)
  $near = New-UnicodeText @(0x8FD1)
  $recent = New-UnicodeText @(0x6700, 0x8FD1)
  $day = New-UnicodeText @(0x5929)
  $seven = New-UnicodeText @(0x4E03)
  $thirty = New-UnicodeText @(0x4E09, 0x5341)

  $recent7 = $near + "7" + $day
  $recent30 = $near + "30" + $day
  $aliases = @(
    @{ canonical = $today; aliases = @($today) },
    @{ canonical = $yesterday; aliases = @($yesterday) },
    @{ canonical = $recent7; aliases = @($recent7, ($recent + "7" + $day), ($near + $seven + $day), ($recent + $seven + $day)) },
    @{ canonical = $recent30; aliases = @($recent30, ($recent + "30" + $day), ($near + $thirty + $day), ($recent + $thirty + $day)) }
  )
  foreach ($item in $aliases) {
    foreach ($alias in @($item.aliases)) {
      if ($QueryCompact -eq (Compact-Text ([string]$alias))) {
        return [string]$item.canonical
      }
    }
  }
  return ""
}

function Get-ActionScore($Action, [string]$Query) {
  $score = 0
  $queryCompact = Compact-Text $Query
  $dateQuickCanonical = Get-DateQuickIntentCanonical $queryCompact
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
  foreach ($name in @("name", "purpose", "context")) {
    if ($Action.PSObject.Properties.Match($name).Count -gt 0 -and $Action.$name) {
      $fields += [string]$Action.$name
    }
  }
  foreach ($alias in @($Action.aliases)) {
    if ($alias) { $fields += [string]$alias }
  }
  if ($Action.PSObject.Properties.Match("locator").Count -gt 0 -and $Action.locator) {
    foreach ($prop in @("dom_text", "dom_placeholder", "trigger_text", "item_text", "button_text", "table_column", "row_action_text", "column_header", "tab_text")) {
      if ($Action.locator.PSObject.Properties.Match($prop).Count -gt 0 -and $Action.locator.$prop) {
        $fields += [string]$Action.locator.$prop
      }
    }
    foreach ($prop in @("tab_texts", "dom_placeholders")) {
      if ($Action.locator.PSObject.Properties.Match($prop).Count -gt 0 -and $Action.locator.$prop) {
        foreach ($value in @($Action.locator.$prop)) {
          if ($value) { $fields += [string]$value }
        }
      }
    }
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
    if ($Query -eq $norm) { $score += 250 }
    elseif ($queryCompact -and $queryCompact -eq $normCompact) { $score += 230 }
    elseif ($Query.Contains($norm) -or $norm.Contains($Query) -or ($queryCompact -and ($queryCompact.Contains($normCompact) -or $normCompact.Contains($queryCompact)))) { $score += 35 }
    else {
      foreach ($part in @([regex]::Split($Query, "[\s,/]+") | Where-Object { $_ })) {
        if ($norm.Contains($part)) { $score += 8 }
      }
    }
  }
  if ($dateQuickCanonical -and
      $Action.PSObject.Properties.Match("type").Count -gt 0 -and $Action.type -eq "date_filter" -and
      $Action.PSObject.Properties.Match("locator").Count -gt 0 -and $Action.locator -and
      $Action.locator.PSObject.Properties.Match("tab_texts").Count -gt 0) {
    $canonicalCompact = Compact-Text $dateQuickCanonical
    foreach ($tabText in @($Action.locator.tab_texts)) {
      $tabCompact = Compact-Text ([string]$tabText)
      if ($tabCompact -and ($tabCompact -eq $canonicalCompact -or $tabCompact -eq $queryCompact)) {
        $score += 320
        break
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
  if ($Action.PSObject.Properties.Match("type").Count -gt 0 -and $Action.type -eq "table_column" -and
      $Action.PSObject.Properties.Match("locator").Count -gt 0 -and $Action.locator -and
      $Action.locator.PSObject.Properties.Match("table_column").Count -gt 0 -and
      $queryCompact -and $queryCompact -eq (Compact-Text ([string]$Action.locator.table_column))) {
    $score += 80
  }
  if ($Action.PSObject.Properties.Match("type").Count -gt 0 -and ($Action.type -eq "dialog_button" -or $Action.type -eq "dialog_opener")) {
    $dialogButtonWords = @(
      (New-UnicodeText @(0x786E, 0x5B9A)),
      (New-UnicodeText @(0x53D6, 0x6D88)),
      (New-UnicodeText @(0x4FDD, 0x5B58)),
      (New-UnicodeText @(0x63D0, 0x4EA4)),
      (New-UnicodeText @(0x5173, 0x95ED))
    )
    $hasDialogButtonIntent = $false
    foreach ($word in $dialogButtonWords) {
      if ($queryCompact.Contains($word)) {
        $hasDialogButtonIntent = $true
        break
      }
    }
    if ($Action.type -eq "dialog_button") {
      $buttonText = ""
      if ($Action.PSObject.Properties.Match("locator").Count -gt 0 -and $Action.locator -and $Action.locator.PSObject.Properties.Match("button_text").Count -gt 0) {
        $buttonText = Compact-Text ([string]$Action.locator.button_text)
      }
      if ($buttonText -and $queryCompact.Contains($buttonText)) {
        $score += 140
      } elseif ($hasDialogButtonIntent) {
        $score += 40
      }
    } elseif ($Action.type -eq "dialog_opener" -and $hasDialogButtonIntent) {
      $score -= 120
    }
  }
  return $score
}

function Get-SafetyMode([string]$Safety) {
  if ($Safety -like "confirmation_required_export*") { return "confirmation_required_export" }
  if ($Safety -like "confirmation_required*") { return "confirmation_required_write" }
  if ($Safety -in @("read_filter", "navigation", "view_setting", "account_menu", "opens_dialog_no_submit", "form_field")) { return "safe_execute_allowed" }
  return "dry_run_only_unknown_safety"
}

function Get-LocatorStrategy($Action) {
  $locator = $Action.locator
  $type = [string]$Action.type
  if ($locator) {
    if ($locator.row_context_required) { return "row_context_required_dialog" }
    if ($locator.trigger_selector -and $locator.item_text) { return "click_trigger_selector_then_overlay_item_text" }
    if ($locator.trigger_selector -and $locator.button_text) { return "click_trigger_selector_then_dialog_button_text" }
    if ($locator.trigger_selector) { return "click_trigger_selector" }
    if ($locator.table_selector -and $locator.row_action_text) { return "click_first_matching_row_action_in_table" }
    if ($locator.selector) { return "click_css_selector" }
    if ($locator.href) { return "navigate_href" }
    if ($locator.dom_text) { return "click_visible_dom_text" }
    if ($locator.dom_placeholder) { return "input_or_filter_placeholder" }
    if ($locator.tab_texts -and $locator.dom_placeholders) { return "click_quick_tab_text_or_placeholder_list" }
    if ($locator.tab_texts) { return "click_visible_tab_text_from_list" }
    if ($locator.dom_placeholders) { return "input_or_filter_placeholder_list" }
    if ($type -eq "table_column" -and $locator.table_column) { return "read_table_column_header" }
    if ($locator.table_column) { return "row_context_required_column_header" }
    if ($locator.uia_name) { return "uia_locator" }
  }
  $name = [string]$Action.name
  $genericTabNames = @(
    (New-UnicodeText @(0x5E73, 0x53F0, 0x6807, 0x7B7E))
  )
  $genericRowNames = @(
    (New-UnicodeText @(0x884C, 0x5206, 0x6790)),
    (New-UnicodeText @(0x64CD, 0x4F5C))
  )
  if ($name -and ($type -in @("tab", "status_tab")) -and ($name -notin $genericTabNames)) { return "click_visible_action_text" }
  if ($name -and $type -eq "row_navigation" -and ($name -notin $genericRowNames)) { return "click_visible_action_text" }
  if ($name -and $type -eq "date_filter") { return "click_visible_filter_label_or_text" }
  if (!$locator) { return "no_locator" }
  return "best_effort_locator"
}

function Get-ActionContext($Action) {
  $locator = $Action.locator
  if (!$locator) { return "" }
  if ($locator.trigger_text -and $locator.item_text) { return ("{0} -> {1}" -f $locator.trigger_text, $locator.item_text) }
  if ($locator.trigger_text -and $locator.button_text) { return ("{0} -> {1}" -f $locator.trigger_text, $locator.button_text) }
  if ($locator.dialog_title -and $locator.button_text) { return ("{0} -> {1}" -f $locator.dialog_title, $locator.button_text) }
  if ($locator.column_header -and $locator.row_action_text) { return ("{0} -> {1}" -f $locator.column_header, $locator.row_action_text) }
  if ($locator.row_action_text) { return [string]$locator.row_action_text }
  if ($locator.table_column) { return ("column:{0}" -f $locator.table_column) }
  if ($locator.tab_texts -and $locator.dom_placeholders) { return ("tabs:{0}; placeholders:{1}" -f ((@($locator.tab_texts) | Select-Object -Unique) -join "/"), ((@($locator.dom_placeholders) | Select-Object -Unique) -join "/")) }
  if ($locator.tab_texts) { return ("tabs:{0}" -f ((@($locator.tab_texts) | Select-Object -Unique) -join "/")) }
  if ($locator.dom_placeholders) { return ("placeholders:{0}" -f ((@($locator.dom_placeholders) | Select-Object -Unique) -join "/")) }
  if ($locator.dom_placeholder) { return ("placeholder:{0}" -f $locator.dom_placeholder) }
  if ($locator.dom_text) { return ("text:{0}" -f $locator.dom_text) }
  if ($locator.href) { return ("href:{0}" -f $locator.href) }
  if ($locator.uia_name) { return ("uia:{0}" -f $locator.uia_name) }
  if ($locator.selector) { return ("selector:{0}" -f $locator.selector) }
  $type = [string]$Action.type
  $name = [string]$Action.name
  if ($type -and $name) { return ("{0}:{1}" -f $type, $name) }
  if ($name) { return $name }
  if ($type) { return $type }
  return ""
}

function Add-ActionMetadata($Action) {
  $mode = Get-SafetyMode ([string]$Action.safety)
  $strategy = Get-LocatorStrategy $Action
  $context = Get-ActionContext $Action
  $confirmationRequired = ($mode -eq "confirmation_required_write" -or $mode -eq "confirmation_required_export" -or $mode -eq "dry_run_only_unknown_safety")
  $Action | Add-Member -NotePropertyName safety_mode -NotePropertyValue $mode -Force
  $Action | Add-Member -NotePropertyName locator_strategy -NotePropertyValue $strategy -Force
  $Action | Add-Member -NotePropertyName context -NotePropertyValue $context -Force
  $Action | Add-Member -NotePropertyName confirmation_required -NotePropertyValue ([bool]$confirmationRequired) -Force
  return $Action
}

function Get-PageRouteHref($Page) {
  $routeValue = ""
  if ($Page.PSObject.Properties.Match("route").Count -gt 0 -and $Page.route) {
    $routeValue = [string]$Page.route
  } elseif ($Page.PSObject.Properties.Match("url_contains").Count -gt 0 -and $Page.url_contains) {
    $routeValue = [string](@($Page.url_contains | Where-Object { $_ }) | Select-Object -First 1)
  }
  if (!$routeValue) { return "" }
  if ($routeValue -match "^[A-Za-z][A-Za-z0-9+.-]*://") { return $routeValue }
  if (!$routeValue.StartsWith("/")) { $routeValue = "/" + $routeValue }
  return "https://erp.xinjianerp.com$routeValue"
}

function Test-PageNameIntent($Page, [string]$QueryCompact, [string[]]$CommandWords) {
  if (!$QueryCompact) { return $false }
  $pageNameCompact = Compact-Text ([string]$Page.name)
  if (!$pageNameCompact) { return $false }
  if ($QueryCompact -eq $pageNameCompact -or $QueryCompact.Contains($pageNameCompact)) { return $true }
  $withoutCommands = [string]$QueryCompact
  foreach ($word in @($CommandWords)) {
    if ($word) {
      $withoutCommands = $withoutCommands.Replace($word, "")
    }
  }
  return ($withoutCommands -and ($withoutCommands -eq $pageNameCompact -or $withoutCommands.Contains($pageNameCompact)))
}

function New-PageNavigationAction($Page) {
  $href = Get-PageRouteHref $Page
  if (!$href) { return $null }
  $routeLabel = ""
  if ($Page.PSObject.Properties.Match("route").Count -gt 0 -and $Page.route) {
    $routeLabel = [string]$Page.route
  }
  $pageId = if ($Page.id) { [string]$Page.id } else { (Get-RouteKey $routeLabel).Trim("/").Replace("/", ".") }
  $aliases = @([string]$Page.name)
  if ($routeLabel) { $aliases += $routeLabel }
  return [pscustomobject]@{
    id = "synthetic.page.navigation.$pageId"
    name = [string]$Page.name
    aliases = @($aliases | Where-Object { $_ } | Select-Object -Unique)
    type = "navigation"
    safety = "navigation"
    purpose = "Navigate to the $($Page.name) page."
    function_source = "synthesized from catalog page route for page-name intent"
    source_map = "page_navigation"
    locator = [pscustomobject]@{
      dom_text = [string]$Page.name
      href = $href
    }
  }
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
$dialogMap = $null
if (!$NoDialogMap -and (Test-Path -LiteralPath $DialogMapPath)) {
  try {
    $dialogMap = Get-Content -LiteralPath $DialogMapPath -Raw -Encoding UTF8 | ConvertFrom-Json
  } catch {
    $dialogMap = $null
  }
}
$rowActionMap = $null
if (!$NoRowActionMap -and (Test-Path -LiteralPath $RowActionMapPath)) {
  try {
    $rowActionMap = Get-Content -LiteralPath $RowActionMapPath -Raw -Encoding UTF8 | ConvertFrom-Json
  } catch {
    $rowActionMap = $null
  }
}
$catalog = $null
$catalogSourceMode = "raw_maps"
if (!$NoCatalog -and (Test-Path -LiteralPath $CatalogPath)) {
  try {
    $catalog = Get-Content -LiteralPath $CatalogPath -Raw -Encoding UTF8 | ConvertFrom-Json
  } catch {
    $catalog = $null
  }
}

if ($catalog -and $catalog.pages) {
  $catalogSourceMode = "action_catalog"
  $globalCatalogPages = @($catalog.pages | Where-Object { [string]$_.id -eq "global" })
  $allPages = @($catalog.pages | Where-Object { [string]$_.id -ne "global" })
  $allGlobalActions = @($globalCatalogPages | ForEach-Object { @($_.actions) })
} else {
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
  if ($dialogMap -and $dialogMap.pages) {
    foreach ($page in @($dialogMap.pages)) {
      $allPages += $page
    }
  }
  if ($rowActionMap -and $rowActionMap.pages) {
    foreach ($page in @($rowActionMap.pages)) {
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
  if ($dialogMap -and $dialogMap.global_actions) {
    $allGlobalActions += @($dialogMap.global_actions)
  }
  if ($rowActionMap -and $rowActionMap.global_actions) {
    $allGlobalActions += @($rowActionMap.global_actions)
  }
}
$query = Normalize-Text $Intent
$route = Get-RoutePath $Url
$queryCompact = Compact-Text $query
$dateQuickCanonical = Get-DateQuickIntentCanonical $queryCompact
$openOrChooseIntentWords = @(
  (New-UnicodeText @(0x6253, 0x5F00)),
  (New-UnicodeText @(0x5C55, 0x5F00)),
  (New-UnicodeText @(0x9009, 0x62E9)),
  (New-UnicodeText @(0x7B5B, 0x9009)),
  (New-UnicodeText @(0x5207, 0x6362))
)
$hasOpenOrChooseIntent = $false
foreach ($word in $openOrChooseIntentWords) {
  if ($queryCompact -and $queryCompact.Contains($word)) {
    $hasOpenOrChooseIntent = $true
    break
  }
}

$matchedPages = @()
$urlMatchedPages = @()
$nameMatchedPages = @()
foreach ($page in @($allPages)) {
  $pageScore = 0
  $routeMatched = $false
  $urlContainsMatched = $false
  $nameMatched = $false
  if ($route -and $page.route_pattern -and $route -match $page.route_pattern) { $pageScore += 100 }
  if ($route -and $page.route_pattern -and $route -match $page.route_pattern) { $routeMatched = $true }
  if ($Url -and $page.url_contains) {
    foreach ($needle in @($page.url_contains)) {
      if ($Url -like "*$needle*") {
        $pageScore += 50
        $urlContainsMatched = $true
      }
    }
  }
  if ($query -and ((Normalize-Text $page.name).Contains($query) -or $query.Contains((Normalize-Text $page.name)))) {
    $pageScore += 30
    $nameMatched = $true
  }
  if ($pageScore -gt 0) {
    $item = [pscustomobject]@{
      page = $page
      score = $pageScore
      route_matched = $routeMatched
      url_contains_matched = $urlContainsMatched
      name_matched = $nameMatched
      current_url_match = ($routeMatched -or $urlContainsMatched)
    }
    if ($item.current_url_match) { $urlMatchedPages += $item }
    if ($nameMatched) { $nameMatchedPages += $item }
    $matchedPages += $item
  }
}
if ($Url -and $urlMatchedPages.Count -gt 0) {
  $matchedPages = @($urlMatchedPages)
}
if ($matchedPages.Count -eq 0 -and !$Url) {
  $matchedPages = @($allPages | ForEach-Object {
      [pscustomobject]@{
        page = $_
        score = 0
        route_matched = $false
        url_contains_matched = $false
        name_matched = $false
        current_url_match = $false
      }
    })
}

$candidates = @()
foreach ($action in @($allGlobalActions)) {
  $score = Get-ActionScore -Action $action -Query $query
  if ($score -gt 0) {
    $action = Add-ActionMetadata $action
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
      $action = Add-ActionMetadata $action
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

$pageActionCandidateCount = @($candidates | Where-Object { $_.match_scope -eq "page" }).Count
$pageNavigationMatchedPages = @()
$seenPageNavigationKeys = @{}
foreach ($matched in @($matchedPages + $nameMatchedPages)) {
  if (!$matched -or !$matched.page) { continue }
  $pageKey = if ($matched.page.id) { [string]$matched.page.id } else { Get-PageRouteHref $matched.page }
  if (!$pageKey -or $seenPageNavigationKeys.ContainsKey($pageKey)) { continue }
  if (!(Test-PageNameIntent -Page $matched.page -QueryCompact $queryCompact -CommandWords $openOrChooseIntentWords)) { continue }
  if ($Url -and $urlMatchedPages.Count -gt 0 -and !$matched.current_url_match -and !$hasOpenOrChooseIntent -and $pageActionCandidateCount -gt 0) {
    continue
  }
  $pageNavigationAction = New-PageNavigationAction $matched.page
  if (!$pageNavigationAction) { continue }
  $seenPageNavigationKeys[$pageKey] = $true
  $pageNavigationAction = Add-ActionMetadata $pageNavigationAction
  $pageNavigationScore = 360 + [int]($matched.score / 5)
  if ($matched.current_url_match) { $pageNavigationScore += 60 }
  if ($hasOpenOrChooseIntent) { $pageNavigationScore += 80 }
  if ($queryCompact -eq (Compact-Text ([string]$matched.page.name))) { $pageNavigationScore += 80 }
  $candidate = [pscustomobject]@{
    score = $pageNavigationScore
    match_scope = "page_navigation"
    page_id = $matched.page.id
    page_name = $matched.page.name
    action = $pageNavigationAction
  }
  $pageNavigationMatchedPages += $matched
  $candidates += $candidate
}

$suppressedGlobalMatches = 0
if ($Url -and $urlMatchedPages.Count -gt 0) {
  $pageCandidateCount = @($candidates | Where-Object { $_.match_scope -in @("page", "page_navigation") }).Count
  if ($pageCandidateCount -gt 0) {
    $globalCandidates = @($candidates | Where-Object { $_.match_scope -eq "global" })
    $suppressedGlobalMatches = $globalCandidates.Count
    $candidates = @($candidates | Where-Object { $_.match_scope -ne "global" })
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
    if ($action.source_map -eq "page_navigation") { $rank += 90 }
    if ($action.type -eq "button" -or $action.type -eq "batch_action") { $rank += 10 }
    if ($action.type -eq "filter_input") { $rank += 16 }
    if ($action.type -eq "filter_dropdown") { $rank += 12 }
    if ($action.type -eq "table_column") { $rank += 8 }
    if ($action.type -eq "overlay_item") { $rank += 12 }
    if ($action.type -eq "overlay_trigger") { $rank -= 5 }
    if ($action.type -eq "dialog_button") { $rank += 14 }
    if ($action.type -eq "dialog_opener") { $rank += 4 }
    if ($action.type -eq "row_action") { $rank += 12 }
    if ($action.safety -eq "read_filter") { $rank += 8 }
    if ([string]$action.safety -like "confirmation_required*") { $rank += 6 }
    if ($dateQuickCanonical) {
      if ($action.type -eq "date_filter") { $rank += 120 }
      if ($action.source_map -eq "curated") { $rank += 20 }
      if ($action.type -in @("tab", "status_tab")) { $rank -= 80 }
    }
    if ($hasOpenOrChooseIntent) {
      if ($action.type -eq "overlay_trigger") { $rank += 35 }
      if ($action.type -eq "overlay_item") { $rank += 18 }
      if ($action.type -eq "filter_input") { $rank -= 4 }
      if ($action.type -eq "table_column") { $rank -= 18 }
    }
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
  page_match_mode = if ($Url -and $urlMatchedPages.Count -gt 0) { "current_url_scope" } elseif ($Url) { "url_no_page_match_fallback" } else { "global_or_name_scope" }
  suppressed_off_page_name_matches = if ($Url -and $urlMatchedPages.Count -gt 0) { @($nameMatchedPages | Where-Object { !$_.current_url_match }).Count } else { 0 }
  suppressed_global_matches = $suppressedGlobalMatches
  source_mode = $catalogSourceMode
  catalog_path = if ($catalogSourceMode -eq "action_catalog") { $CatalogPath } else { $null }
  catalog_version = if ($catalog) { $catalog.version } else { $null }
  catalog_totals = if ($catalog) { $catalog.totals } else { $null }
  map_version = $map.version
  auto_map_version = if ($autoMap) { $autoMap.version } else { $null }
  overlay_map_version = if ($overlayMap) { $overlayMap.version } else { $null }
  dialog_map_version = if ($dialogMap) { $dialogMap.version } else { $null }
  row_action_map_version = if ($rowActionMap) { $rowActionMap.version } else { $null }
  map_pages_total = $allPages.Count
  matched_pages = @($matchedPages | Sort-Object score -Descending | Select-Object -First 5 | ForEach-Object {
      [ordered]@{
        id = $_.page.id
        name = $_.page.name
        score = $_.score
        current_url_match = [bool]$_.current_url_match
      }
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
