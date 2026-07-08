[CmdletBinding(PositionalBinding = $false)]
param(
  [int]$ProcessId = 0,
  [string]$Url = "",
  [string]$OutputPath = "",
  [string]$CatalogPath = "",
  [switch]$IncludeDataItems,
  [switch]$CompareCatalog,
  [switch]$Json
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
if (!$CatalogPath) {
  $CatalogPath = Join-Path $root "references\xinjian-ui-action-catalog.json"
}

Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

function Clean-UiText([string]$Text) {
  $chars = @()
  foreach ($ch in ([string]$Text).ToCharArray()) {
    $code = [int][char]$ch
    if ($code -ge 0xE000 -and $code -le 0xF8FF) {
      $chars += " "
    } else {
      $chars += [string]$ch
    }
  }
  $value = ($chars -join "")
  $value = [regex]::Replace($value, "^\s*-\d+-\d+x\s*", "")
  $value = [regex]::Replace($value, "\s+", " ").Trim()
  return $value
}

function Normalize-BrowserUrl([string]$Value) {
  $text = ([string]$Value).Trim()
  if (!$text) { return $null }
  if ($text -match "^(?i)(chrome|edge|about|devtools|view-source):") { return $null }
  if ($text -match "^(?i)https?://") { return $text }
  if ($text -match "^[A-Za-z0-9.-]+\.[A-Za-z]{2,}(/.*)?$") {
    return "https://$text"
  }
  return $null
}

function Redact-UrlForOutput([string]$InputUrl) {
  if (!$InputUrl) { return $null }
  return ([regex]::Replace(
      $InputUrl,
      "(?i)([?&][^=]*(token|secret|password|passwd|pwd|cookie|session|auth|key|code)[^=]*=)[^&#]*",
      '${1}[redacted]'
    ))
}

function Get-ValuePatternText($Element) {
  try {
    $pattern = $Element.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)
    return [string]$pattern.Current.Value
  } catch {
    return $null
  }
}

function Get-AddressBarUrl($RootElement) {
  $edits = $RootElement.FindAll(
    [System.Windows.Automation.TreeScope]::Subtree,
    [System.Windows.Automation.PropertyCondition]::new(
      [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
      [System.Windows.Automation.ControlType]::Edit
    )
  )
  foreach ($edit in $edits) {
    $url = Normalize-BrowserUrl (Get-ValuePatternText $edit)
    if ($url) { return $url }
  }
  return $null
}

function Get-Patterns($Element) {
  $patterns = @()
  foreach ($pattern in @(
      [System.Windows.Automation.InvokePattern]::Pattern,
      [System.Windows.Automation.SelectionItemPattern]::Pattern,
      [System.Windows.Automation.ExpandCollapsePattern]::Pattern,
      [System.Windows.Automation.ValuePattern]::Pattern,
      [System.Windows.Automation.TogglePattern]::Pattern
    )) {
    try {
      $tmp = $null
      if ($Element.TryGetCurrentPattern($pattern, [ref]$tmp)) {
        $patterns += ($pattern.ProgrammaticName -replace "PatternIdentifiers\.Pattern$", "")
      }
    } catch {
    }
  }
  return @($patterns)
}

function Get-RectObject($Rect) {
  if ($Rect.IsEmpty) { return $null }
  return [ordered]@{
    x = [int][Math]::Round($Rect.X)
    y = [int][Math]::Round($Rect.Y)
    width = [int][Math]::Round($Rect.Width)
    height = [int][Math]::Round($Rect.Height)
  }
}

function Get-RoutePath([string]$InputUrl) {
  try {
    $uri = [uri]$InputUrl
    return $uri.AbsolutePath
  } catch {
    return ""
  }
}

function Get-RouteKey([string]$InputUrl) {
  $route = Get-RoutePath $InputUrl
  if (!$route) { $route = [string]$InputUrl }
  if (!$route) { return "" }
  if (!$route.StartsWith("/")) { $route = "/" + $route }
  if ($route.Length -gt 1) { $route = $route.TrimEnd("/") }
  return $route.ToLowerInvariant()
}

function Normalize-CatalogText([string]$Text) {
  $value = Clean-UiText $Text
  if (!$value) { return "" }
  $value = [regex]::Replace($value, "\s+\d+$", "")
  $value = $value -replace "ＩＤ", "ID"
  return $value.Trim().ToLowerInvariant()
}

function Join-Codepoints([int[]]$Codes) {
  return -join ($Codes | ForEach-Object { [char]$_ })
}

function Test-ContainsUiWord([string]$Name, [string[]]$Words) {
  foreach ($word in $Words) {
    if ($word -and $Name.Contains($word)) { return $true }
  }
  return $false
}

function Test-ActionButtonName([string]$Name) {
  if (!$Name) { return $false }
  if ($Name -match "^[\u00D7xX]+$") { return $false }
  return (Test-ContainsUiWord $Name @(
      (Join-Codepoints @(25628, 32034)), # search
      (Join-Codepoints @(26597, 35810)), # query
      (Join-Codepoints @(37325, 32622)), # reset
      (Join-Codepoints @(20445, 23384)), # save
      (Join-Codepoints @(37197, 32622)), # config / assign second word overlap is acceptable for button keep
      (Join-Codepoints @(20998, 37197)), # assign
      (Join-Codepoints @(35748, 39046)), # claim
      (Join-Codepoints @(25209, 37327)), # batch
      (Join-Codepoints @(25805, 20316)), # operate
      (Join-Codepoints @(23548, 20986)), # export
      (Join-Codepoints @(19979, 36733)), # download
      (Join-Codepoints @(26032, 22686)), # add new
      (Join-Codepoints @(32534, 36753)), # edit
      (Join-Codepoints @(21024, 38500)), # delete
      (Join-Codepoints @(35814, 24773)), # details
      (Join-Codepoints @(35774, 32622)), # settings
      (Join-Codepoints @(30830, 35748)), # confirm
      (Join-Codepoints @(21462, 28040)), # cancel
      (Join-Codepoints @(25552, 20132)), # submit
      (Join-Codepoints @(21516, 27493)), # sync
      (Join-Codepoints @(21047, 26032)), # refresh
      (Join-Codepoints @(22797, 21046)), # copy
      (Join-Codepoints @(24674, 22797)), # restore
      (Join-Codepoints @(36716, 31227)), # transfer
      (Join-Codepoints @(40657, 21517, 21333)), # blacklist
      (Join-Codepoints @(26631, 31614)), # tag
      (Join-Codepoints @(39044, 35686)), # warning
      (Join-Codepoints @(28155, 21152)), # add
      (Join-Codepoints @(31227, 38500)), # remove
      (Join-Codepoints @(21551, 29992)), # enable
      (Join-Codepoints @(20572, 29992)), # disable
      (Join-Codepoints @(23457, 26680)), # review
      (Join-Codepoints @(26597, 30475)), # view
      (Join-Codepoints @(20851, 38381))  # close
    ))
}

function Get-ControlRole([string]$Type, [string]$Name, [string[]]$Patterns) {
  if ($Type -eq "Edit") { return "filter_or_input" }
  if ($Type -eq "TabItem") { return "status_tab" }
  if ($Type -eq "MenuItem" -or $Type -eq "Hyperlink") {
    if ($Patterns -contains "ExpandCollapse") { return "navigation_group" }
    return "navigation_link"
  }
  if ($Type -eq "Button") {
    if (Test-ContainsUiWord $Name @((Join-Codepoints @(25628, 32034)), (Join-Codepoints @(26597, 35810)))) { return "search_button" }
    if (Test-ContainsUiWord $Name @((Join-Codepoints @(37325, 32622)))) { return "reset_button" }
    if ((Test-ContainsUiWord $Name @((Join-Codepoints @(20445, 23384)))) -and (Test-ContainsUiWord $Name @((Join-Codepoints @(37197, 32622))))) { return "save_layout_button" }
    if (Test-ContainsUiWord $Name @((Join-Codepoints @(20998, 37197)))) { return "write_assign_button" }
    if (Test-ContainsUiWord $Name @((Join-Codepoints @(35748, 39046)))) { return "write_claim_button" }
    if (Test-ContainsUiWord $Name @((Join-Codepoints @(25209, 37327)))) { return "batch_action_menu" }
    return "button"
  }
  if ($Type -eq "Text" -and $Name -match "^(BI|ERP|ADS|CRM|设置)$") { return "top_module_switch" }
  if ($Type -eq "DataItem") { return "table_column_or_cell" }
  return "visible_text"
}

function Test-KeepControl([string]$Type, [string]$Name) {
  if (!$Name -or $Name -match "^[\u00D7xX]+$") { return $false }
  if ($Type -eq "Button") {
    return (Test-ActionButtonName $Name)
  }
  if ($Type -eq "ListItem" -and $Name -match "^\d+$") {
    return $false
  }
  if ($Type -in @("Edit", "MenuItem", "Hyperlink", "TabItem", "ListItem", "ComboBox", "CheckBox", "RadioButton")) {
    return $true
  }
  if ($Type -eq "Text" -and $Name -match "^(BI|ERP|ADS|CRM|设置|小程序|我的任务|首页|订单统计|受限页面|达人公海)$") {
    return $true
  }
  if ($Type -eq "DataItem") {
    if ($IncludeDataItems) { return $true }
    return ($Name -match "^(画像 / 品类|粉丝数|GMV|Item Sold|达人标签|跟进商务|状态|交互时间)$")
  }
  return $false
}

function Get-CatalogActionIndex([string]$InputUrl) {
  $index = @{
    terms = @{}
  }
  $summary = [ordered]@{
    enabled = [bool]$CompareCatalog
    available = $false
    catalog_path = $CatalogPath
    page_count = 0
    action_count = 0
  }
  if (!$CompareCatalog) {
    return [pscustomobject]@{ summary = [pscustomobject]$summary; terms = $index.terms }
  }
  if (!(Test-Path -LiteralPath $CatalogPath)) {
    return [pscustomobject]@{ summary = [pscustomobject]$summary; terms = $index.terms }
  }
  try {
    $catalog = Get-Content -LiteralPath $CatalogPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $routeKey = Get-RouteKey $InputUrl
    $routePath = Get-RoutePath $InputUrl
    $pages = @($catalog.pages | Where-Object {
        $pageRouteKey = Get-RouteKey ([string]$_.route)
        ($routeKey -and $pageRouteKey -eq $routeKey) -or
          ($routePath -and $_.route_pattern -and $routePath -match ([string]$_.route_pattern)) -or
          ([string]$_.id -eq "global")
      })
    foreach ($page in $pages) {
      foreach ($action in @($page.actions)) {
        $terms = @([string]$action.name) + @($action.aliases | ForEach-Object { [string]$_ })
        if ($action.context) { $terms += [string]$action.context }
        if ($action.locator) {
          foreach ($prop in @("dom_text", "dom_placeholder", "trigger_text", "item_text", "button_text", "table_column", "row_action_text")) {
            if ($action.locator.PSObject.Properties.Match($prop).Count -gt 0 -and $action.locator.$prop) {
              $terms += [string]$action.locator.$prop
            }
          }
        }
        foreach ($term in $terms) {
          $key = Normalize-CatalogText $term
          if (!$key) { continue }
          if (!$index.terms.ContainsKey($key)) { $index.terms[$key] = @() }
          $index.terms[$key] += [string]$action.id
        }
      }
    }
    $summary.available = $true
    $summary.page_count = $pages.Count
    $summary.action_count = @($pages | ForEach-Object { @($_.actions).Count } | Measure-Object -Sum).Sum
  } catch {
    $summary.error = $_.Exception.Message
  }
  return [pscustomobject]@{ summary = [pscustomobject]$summary; terms = $index.terms }
}

function Find-XinjianProcess {
  if ($ProcessId -gt 0) {
    return Get-Process -Id $ProcessId -ErrorAction Stop
  }
  $candidates = @(Get-Process -Name chrome,msedge,ziniaobrowser -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle -match "\u5fc3\u8230|xinjian|Xinjian" })
  if ($Url) {
    $targetUrl = Normalize-BrowserUrl $Url
    if (!$targetUrl) { $targetUrl = $Url }
    foreach ($candidate in $candidates) {
      try {
        $candidateRoot = [System.Windows.Automation.AutomationElement]::FromHandle($candidate.MainWindowHandle)
        $candidateUrl = Get-AddressBarUrl $candidateRoot
        if ($candidateUrl -and ($candidateUrl -eq $targetUrl -or $candidateUrl.Contains($targetUrl) -or $targetUrl.Contains($candidateUrl))) {
          return $candidate
        }
      } catch {
      }
    }
  }
  return @($candidates | Select-Object -First 1)[0]
}

$process = Find-XinjianProcess
if (!$process) {
  $payload = [ordered]@{
    ok = $false
    error = "xinjian_window_not_found"
    message = "No visible Xinjian browser window was found."
  }
  if ($Json) { $payload | ConvertTo-Json -Depth 6 } else { Write-Host $payload.message }
  exit 2
}

$windowRoot = [System.Windows.Automation.AutomationElement]::FromHandle($process.MainWindowHandle)
$pageUrl = Redact-UrlForOutput (Get-AddressBarUrl $windowRoot)
$catalogIndex = Get-CatalogActionIndex -InputUrl $pageUrl
$document = $windowRoot.FindFirst(
  [System.Windows.Automation.TreeScope]::Subtree,
  [System.Windows.Automation.PropertyCondition]::new(
    [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
    [System.Windows.Automation.ControlType]::Document
  )
)
if (!$document) {
  $payload = [ordered]@{
    ok = $false
    error = "xinjian_document_not_found"
    process_id = $process.Id
    window_title = $process.MainWindowTitle
  }
  if ($Json) { $payload | ConvertTo-Json -Depth 6 } else { Write-Host "Xinjian document element not found." }
  exit 3
}

$items = $document.FindAll([System.Windows.Automation.TreeScope]::Subtree, [System.Windows.Automation.Condition]::TrueCondition)
$controls = @()
for ($i = 0; $i -lt $items.Count; $i++) {
  $element = $items.Item($i)
  $rawName = [string]$element.Current.Name
  $name = Clean-UiText $rawName
  if (!$name) { continue }
  $type = ([string]$element.Current.ControlType.ProgrammaticName) -replace "^ControlType\.", ""
  if (!(Test-KeepControl -Type $type -Name $name)) { continue }
  $patterns = @(Get-Patterns $element)
  $record = [ordered]@{
      index = $i
      type = $type
      name = $name
      role = Get-ControlRole -Type $type -Name $name -Patterns $patterns
      patterns = $patterns
      bounds = Get-RectObject $element.Current.BoundingRectangle
    }
  if ($CompareCatalog) {
    $catalogKey = Normalize-CatalogText $name
    $matchedIds = @()
    if ($catalogKey -and $catalogIndex.terms.ContainsKey($catalogKey)) {
      $matchedIds = @($catalogIndex.terms[$catalogKey] | Select-Object -Unique)
    }
    $record.catalog_match = ($matchedIds.Count -gt 0)
    $record.catalog_action_ids = @($matchedIds)
  }
  $controls += [pscustomobject]$record
}

$catalogCompare = $catalogIndex.summary
if ($CompareCatalog) {
  $matchedControls = @($controls | Where-Object { $_.catalog_match })
  $navigationControls = @($controls | Where-Object { $_.role -in @("top_module_switch", "navigation_link", "navigation_group") })
  $missingControls = @($controls | Where-Object {
      !$_.catalog_match -and $_.role -notin @("top_module_switch", "navigation_link", "navigation_group")
    })
  $catalogCompare | Add-Member -NotePropertyName matched_controls -NotePropertyValue $matchedControls.Count -Force
  $catalogCompare | Add-Member -NotePropertyName navigation_controls -NotePropertyValue $navigationControls.Count -Force
  $catalogCompare | Add-Member -NotePropertyName missing_controls_count -NotePropertyValue $missingControls.Count -Force
  $catalogCompare | Add-Member -NotePropertyName missing_controls -NotePropertyValue @($missingControls | Select-Object type, role, name) -Force
}

$stamp = "{0}-{1}" -f (Get-Date -Format "yyyyMMdd-HHmmss-fff"), ([guid]::NewGuid().ToString("N").Substring(0, 8))
if (!$OutputPath) {
  $dir = Join-Path $root ".ziniao-ops\xinjian-ui-observations"
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $OutputPath = Join-Path $dir "$stamp.json"
}

$payload = [ordered]@{
  ok = $true
  captured_at = (Get-Date).ToString("o")
  source = "windows_uia_read_only"
  process = [ordered]@{
    id = $process.Id
    name = $process.ProcessName
    window_title = $process.MainWindowTitle
  }
  page = [ordered]@{
    title = $document.Current.Name
    url = $pageUrl
    route = Get-RoutePath $pageUrl
  }
  controls_count = $controls.Count
  controls = @($controls)
  catalog_compare = $catalogCompare
  note = "Read-only UIA capture. No click, typing, cookie, localStorage, token, or password was read. Table row data is excluded unless -IncludeDataItems is passed."
}

$payload | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
$payload.output_path = $OutputPath

if ($Json) {
  $payload | ConvertTo-Json -Depth 12
} else {
  Write-Host ("Captured {0} Xinjian UI controls: {1}" -f $controls.Count, $OutputPath)
}
