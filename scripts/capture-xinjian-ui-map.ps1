[CmdletBinding(PositionalBinding = $false)]
param(
  [int]$ProcessId = 0,
  [string]$Url = "",
  [string]$OutputPath = "",
  [switch]$IncludeDataItems,
  [switch]$Json
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path

Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

function Clean-UiText([string]$Text) {
  $value = ([string]$Text)
  $value = [regex]::Replace($value, "[\uE000-\uF8FF]", " ")
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

function Get-ControlRole([string]$Type, [string]$Name, [string[]]$Patterns) {
  if ($Type -eq "Edit") { return "filter_or_input" }
  if ($Type -eq "TabItem") { return "status_tab" }
  if ($Type -eq "MenuItem" -or $Type -eq "Hyperlink") {
    if ($Patterns -contains "ExpandCollapse") { return "navigation_group" }
    return "navigation_link"
  }
  if ($Type -eq "Button") {
    if ($Name -match "搜索|查询") { return "search_button" }
    if ($Name -match "重置") { return "reset_button" }
    if ($Name -match "保存配置") { return "save_layout_button" }
    if ($Name -match "分配") { return "write_assign_button" }
    if ($Name -match "认领") { return "write_claim_button" }
    if ($Name -match "批量") { return "batch_action_menu" }
    return "button"
  }
  if ($Type -eq "Text" -and $Name -match "^(BI|ERP|ADS|CRM|设置)$") { return "top_module_switch" }
  if ($Type -eq "DataItem") { return "table_column_or_cell" }
  return "visible_text"
}

function Test-KeepControl([string]$Type, [string]$Name) {
  if ($Type -in @("Button", "Edit", "MenuItem", "Hyperlink", "TabItem", "ListItem", "ComboBox", "CheckBox", "RadioButton")) {
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
  $controls += [pscustomobject]([ordered]@{
      index = $i
      type = $type
      name = $name
      role = Get-ControlRole -Type $type -Name $name -Patterns $patterns
      patterns = $patterns
      bounds = Get-RectObject $element.Current.BoundingRectangle
    })
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
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
  note = "Read-only UIA capture. No click, typing, cookie, localStorage, token, or password was read. Table row data is excluded unless -IncludeDataItems is passed."
}

$payload | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
$payload.output_path = $OutputPath

if ($Json) {
  $payload | ConvertTo-Json -Depth 12
} else {
  Write-Host ("Captured {0} Xinjian UI controls: {1}" -f $controls.Count, $OutputPath)
}
