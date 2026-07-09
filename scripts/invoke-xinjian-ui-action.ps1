[CmdletBinding(PositionalBinding = $false)]
param(
  [Parameter(Mandatory = $true)]
  [string]$Intent,
  [string]$Url = "",
  [int[]]$Port = @(),
  [switch]$Execute,
  [switch]$AllowWrite,
  [switch]$AllowExport,
  [switch]$NoAutoDetectUrl,
  [int]$CandidateIndex = 0,
  [int]$RowIndex = 0,
  [string]$RowText = "",
  [switch]$Json
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path

function ConvertFrom-JsonText($Lines) {
  $text = (($Lines | Out-String).Trim())
  if (!$text) { return $null }
  try { return $text | ConvertFrom-Json } catch { return $null }
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

function Get-FirstExplicitPort {
  $items = @($Port | Where-Object { $_ -gt 0 } | Sort-Object -Unique)
  if ($items.Count -gt 0) { return [int]$items[0] }
  return $null
}

function Resolve-XinjianCurrentUrlByScript {
  param([string]$QueryIntent = "")
  $resolver = Join-Path $PSScriptRoot "resolve-xinjian-current-url.ps1"
  if (!(Test-Path -LiteralPath $resolver)) {
    return [pscustomobject]@{ ok = $false; reason = "resolver_missing"; candidates = @() }
  }
  $args = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $resolver)
  $args += Get-PortArgumentList -Ports $Port
  if ($QueryIntent) { $args += @("-Intent", $QueryIntent) }
  $args += "-Json"
  $raw = @(& powershell @args 2>&1)
  $parsed = ConvertFrom-JsonText $raw
  if ($parsed) { return $parsed }
  return [pscustomobject]@{ ok = $false; reason = "resolver_output_parse_failed"; raw_output = ($raw | Out-String).Trim(); candidates = @() }
}

function Invoke-XinjianActionQuery {
  param(
    [string]$QueryIntent,
    [string]$QueryUrl
  )
  $queryArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "query-xinjian-ui-action.ps1"), "-Intent", $QueryIntent, "-Json")
  if ($QueryUrl) { $queryArgs += @("-Url", $QueryUrl) }
  $raw = @(& powershell @queryArgs 2>&1)
  [pscustomobject]@{
    raw = $raw
    exit_code = $LASTEXITCODE
    parsed = ConvertFrom-JsonText $raw
  }
}

function Resolve-XinjianUrlByIntent {
  param(
    [string]$QueryIntent,
    [object]$Detection
  )
  $urls = @($Detection.candidates |
    ForEach-Object { [string]$_.url } |
    Where-Object { Test-XinjianUrl $_ } |
    Sort-Object -Unique)
  if ($urls.Count -lt 2) { return $null }
  $scores = @()
  foreach ($candidateUrl in $urls) {
    $probe = Invoke-XinjianActionQuery -QueryIntent $QueryIntent -QueryUrl $candidateUrl
    if (!$probe.parsed -or !$probe.parsed.ok -or @($probe.parsed.matches).Count -eq 0) {
      $scores += [pscustomobject]@{
        url = $candidateUrl
        ok = $false
        score = 0
        rank = 0
        page_name = ""
        action_name = ""
      }
      continue
    }
    $best = @($probe.parsed.matches)[0]
    $scores += [pscustomobject]@{
      url = $candidateUrl
      ok = $true
      score = [int]$best.score
      rank = [int]$best.rank
      page_name = [string]$best.page_name
      action_name = [string]$best.action.name
    }
  }
  $ordered = @($scores | Sort-Object @{ Expression = "score"; Descending = $true }, @{ Expression = "rank"; Descending = $true })
  if ($ordered.Count -eq 0 -or !$ordered[0].ok -or $ordered[0].score -le 0) { return $null }
  if ($ordered.Count -gt 1 -and $ordered[1].ok -and $ordered[1].score -eq $ordered[0].score -and $ordered[1].rank -eq $ordered[0].rank) {
    return $null
  }
  return [pscustomobject]@{
    url = [string]$ordered[0].url
    score = [int]$ordered[0].score
    rank = [int]$ordered[0].rank
    page_name = [string]$ordered[0].page_name
    action_name = [string]$ordered[0].action_name
    candidates = @($ordered)
  }
}

function Get-ForegroundProcessId {
  try {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class ZiniaoOpsNativeWindow {
  [DllImport("user32.dll")]
  public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")]
  public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
}
"@ -ErrorAction SilentlyContinue | Out-Null
    $processIdValue = [uint32]0
    $handle = [ZiniaoOpsNativeWindow]::GetForegroundWindow()
    if ($handle -eq [IntPtr]::Zero) { return $null }
    [void][ZiniaoOpsNativeWindow]::GetWindowThreadProcessId($handle, [ref]$processIdValue)
    if ($processIdValue -gt 0) { return [int]$processIdValue }
  } catch {
  }
  return $null
}

function Test-XinjianUrl([string]$Value) {
  $text = [string]$Value
  return $text -match "^https?://erp\.xinjianerp\.com/" -and $text -notmatch "\s"
}

function Get-XinjianNonBusinessPageReason([string]$Value) {
  if (!$Value) { return "" }
  $routeKey = Get-XinjianRouteKey $Value
  if (!$routeKey) { $routeKey = "/" }
  if ($routeKey -match "^/(login|xtlogin|sso|social-login|redirect)(/|$)") { return "manual_login_required_in_debuggable_xinjian_browser" }
  if ($routeKey -match "^/(401|404)(/|$)" -or $routeKey -match "^/index/(noaccess|ad-no-auth)(/|$)") { return "open_valid_xinjian_business_page" }
  return ""
}

function Get-XinjianRouteKey([string]$Value) {
  if (!$Value) { return "" }
  $path = ""
  try {
    $uri = [uri]$Value
    $path = $uri.AbsolutePath
  } catch {
    $path = [string]$Value
  }
  if (!$path) { return "" }
  if (!$path.StartsWith("/")) { $path = "/" + $path }
  $routeKey = ($path -replace "/+", "/").TrimEnd("/").ToLowerInvariant()
  if (!$routeKey) { return "/" }
  return $routeKey
}

function Get-XinjianPageKind([string]$Value) {
  if (!$Value) { return "unknown" }
  $routeKey = Get-XinjianRouteKey $Value
  if ($routeKey -match "^/(login|xtlogin|sso|social-login|redirect)(/|$)") { return "login_page" }
  if ($routeKey -match "^/(401|404)(/|$)" -or $routeKey -match "^/index/(noaccess|ad-no-auth)(/|$)") { return "non_business_page" }
  return "business_page"
}

function Get-ResolvedTitle($Detection, [string]$InputUrl) {
  if (!$Detection -or !$InputUrl -or $Detection.PSObject.Properties.Match("candidates").Count -eq 0) { return "" }
  $match = @($Detection.candidates | Where-Object { [string]$_.url -eq $InputUrl } | Select-Object -First 1)
  if ($match.Count -gt 0) { return [string]$match[0].title }
  return ""
}

function Get-ResolvedPort($Detection, [string]$InputUrl, [bool]$ExplicitUrlProvided) {
  $explicitPort = Get-FirstExplicitPort
  if ($explicitPort) { return [int]$explicitPort }

  if ($Detection -and $InputUrl -and $Detection.PSObject.Properties.Match("candidates").Count -gt 0) {
    $match = @($Detection.candidates | Where-Object { [string]$_.url -eq $InputUrl -and $_.port } | Select-Object -First 1)
    if ($match.Count -gt 0) { return [int]$match[0].port }
  }

  if (!$ExplicitUrlProvided -and $Detection -and $Detection.PSObject.Properties.Match("resolved_port").Count -gt 0 -and $Detection.resolved_port) {
    return [int]$Detection.resolved_port
  }

  if ($ExplicitUrlProvided -and $Detection -and $Detection.PSObject.Properties.Match("url").Count -gt 0 -and [string]$Detection.url -eq $InputUrl -and $Detection.PSObject.Properties.Match("resolved_port").Count -gt 0 -and $Detection.resolved_port) {
    return [int]$Detection.resolved_port
  }

  return $null
}

function Get-UiaWindowProcessId($Detection, [string]$InputUrl) {
  if (!$Detection -or !$InputUrl -or $Detection.PSObject.Properties.Match("candidates").Count -eq 0) { return $null }
  $match = @($Detection.candidates | Where-Object {
      [string]$_.url -eq $InputUrl -and
      $_.process_id -and
      ([string]$_.source -in @("window_uia", "window_title"))
    } | Select-Object -First 1)
  if ($match.Count -gt 0) { return [int]$match[0].process_id }
  return $null
}

function Get-UiaControlType([string]$TypeName) {
  switch ([string]$TypeName) {
    "Button" { return [System.Windows.Automation.ControlType]::Button }
    "Hyperlink" { return [System.Windows.Automation.ControlType]::Hyperlink }
    "TabItem" { return [System.Windows.Automation.ControlType]::TabItem }
    "MenuItem" { return [System.Windows.Automation.ControlType]::MenuItem }
    "ListItem" { return [System.Windows.Automation.ControlType]::ListItem }
    "ComboBox" { return [System.Windows.Automation.ControlType]::ComboBox }
    "CheckBox" { return [System.Windows.Automation.ControlType]::CheckBox }
    "RadioButton" { return [System.Windows.Automation.ControlType]::RadioButton }
    default { return $null }
  }
}

function Get-UiaActionTerms($Action) {
  $terms = New-Object System.Collections.Generic.List[string]
  $locator = $Action.locator
  if ($locator) {
    foreach ($prop in @("uia_name", "dom_text")) {
      if ($locator.PSObject.Properties.Match($prop).Count -gt 0 -and $locator.$prop) {
        $terms.Add([string]$locator.$prop)
      }
    }
  }
  if ($Action.name) { $terms.Add([string]$Action.name) }
  return @($terms | Where-Object { $_ } | Select-Object -Unique)
}

function Normalize-UiaElementName([string]$Value) {
  $text = ([string]$Value) -replace "[\uE000-\uF8FF]", ""
  $text = $text -replace "\s+", " "
  return $text.Trim()
}

function Find-UiaActionElement {
  param(
    [object]$Root,
    [object]$Action
  )

  $locator = $Action.locator
  $terms = @(Get-UiaActionTerms $Action | ForEach-Object { Normalize-UiaElementName ([string]$_) } | Where-Object { $_ } | Select-Object -Unique)
  $startsWith = ""
  $expectedControlType = $null
  if ($locator) {
    if ($locator.PSObject.Properties.Match("uia_name_starts_with").Count -gt 0 -and $locator.uia_name_starts_with) {
      $startsWith = Normalize-UiaElementName ([string]$locator.uia_name_starts_with)
    }
    if ($locator.PSObject.Properties.Match("uia_type").Count -gt 0 -and $locator.uia_type) {
      $expectedControlType = Get-UiaControlType ([string]$locator.uia_type)
    }
  }
  if ($terms.Count -eq 0 -and !$startsWith) { return $null }

  $items = $Root.FindAll(
    [System.Windows.Automation.TreeScope]::Subtree,
    [System.Windows.Automation.Condition]::TrueCondition
  )
  for ($i = 0; $i -lt $items.Count; $i++) {
    $element = $items.Item($i)
    $name = ([string]$element.Current.Name).Trim()
    $normalizedName = Normalize-UiaElementName $name
    if (!$normalizedName) { continue }
    if ($expectedControlType -and $element.Current.ControlType -ne $expectedControlType) { continue }
    try {
      if (!$element.Current.IsEnabled -or $element.Current.IsOffscreen) { continue }
    } catch {
      continue
    }

    $matched = $false
    foreach ($term in $terms) {
      if ($normalizedName -eq $term) {
        $matched = $true
        break
      }
    }
    if (!$matched -and $startsWith -and $normalizedName.StartsWith($startsWith, [System.StringComparison]::OrdinalIgnoreCase)) {
      $matched = $true
    }
    if (!$matched) { continue }
    return $element
  }
  return $null
}

function Test-UiaActionExecutable {
  param(
    [object]$Action,
    [string]$InputUrl,
    [object]$Detection
  )
  if ($Action.PSObject.Properties.Match("locator").Count -eq 0 -or !$Action.locator) { return $false }
  $processId = Get-UiaWindowProcessId -Detection $Detection -InputUrl $InputUrl
  if (!$processId) { return $false }
  $locator = $Action.locator
  $eligibleByLocator = $false
  if ($locator.PSObject.Properties.Match("uia_type").Count -gt 0 -and $locator.uia_type -and ([string]$locator.uia_type -in @("Button", "Hyperlink", "TabItem", "MenuItem", "ListItem", "RadioButton"))) {
    $eligibleByLocator = $true
  }
  if ($locator.PSObject.Properties.Match("uia_name").Count -gt 0 -and $locator.uia_name -and ([string]$Action.type -in @("button", "tab", "status_tab", "navigation", "row_navigation"))) {
    $eligibleByLocator = $true
  }
  if (!$eligibleByLocator) { return $false }

  try {
    Add-Type -AssemblyName UIAutomationClient -ErrorAction Stop
    Add-Type -AssemblyName UIAutomationTypes -ErrorAction Stop
    $process = Get-Process -Id $processId -ErrorAction Stop
    if (!$process.MainWindowHandle -or $process.MainWindowHandle -eq [IntPtr]::Zero) { return $false }
    $rootElement = [System.Windows.Automation.AutomationElement]::FromHandle($process.MainWindowHandle)
    $element = Find-UiaActionElement -Root $rootElement -Action $Action
    if (!$element) { return $false }
    $pattern = $null
    if ($element.TryGetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern, [ref]$pattern)) { return $true }
    $pattern = $null
    if ($element.TryGetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern, [ref]$pattern)) { return $true }
  } catch {
    return $false
  }
  return $false
}

function Invoke-XinjianUiaAction {
  param(
    [object]$Action,
    [string]$InputUrl,
    [object]$Detection
  )

  try {
    Add-Type -AssemblyName UIAutomationClient -ErrorAction Stop
    Add-Type -AssemblyName UIAutomationTypes -ErrorAction Stop
  } catch {
    return [pscustomobject]@{ ok = $false; backend = "uia"; error = "uia_automation_unavailable"; message = $_.Exception.Message }
  }

  $processId = Get-UiaWindowProcessId -Detection $Detection -InputUrl $InputUrl
  if (!$processId) {
    return [pscustomobject]@{ ok = $false; backend = "uia"; error = "uia_window_not_resolved" }
  }
  try {
    $process = Get-Process -Id $processId -ErrorAction Stop
  } catch {
    return [pscustomobject]@{ ok = $false; backend = "uia"; error = "uia_window_process_missing"; process_id = $processId }
  }
  if (!$process.MainWindowHandle -or $process.MainWindowHandle -eq [IntPtr]::Zero) {
    return [pscustomobject]@{ ok = $false; backend = "uia"; error = "uia_window_handle_missing"; process_id = $processId }
  }

  try {
    $rootElement = [System.Windows.Automation.AutomationElement]::FromHandle($process.MainWindowHandle)
    $element = Find-UiaActionElement -Root $rootElement -Action $Action
  } catch {
    return [pscustomobject]@{ ok = $false; backend = "uia"; error = "uia_element_search_failed"; process_id = $processId; message = $_.Exception.Message }
  }
  if (!$element) {
    return [pscustomobject]@{ ok = $false; backend = "uia"; error = "uia_element_not_found"; process_id = $processId; action_name = [string]$Action.name }
  }

  $matchedName = [string]$element.Current.Name
  $matchedType = ([string]$element.Current.ControlType.ProgrammaticName) -replace "^ControlType\.", ""
  try {
    $pattern = $null
    if ($element.TryGetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern, [ref]$pattern)) {
      $pattern.Invoke()
      return [pscustomobject]@{
        ok = $true
        backend = "uia"
        pattern = "InvokePattern"
        process_id = $processId
        window_title = [string]$process.MainWindowTitle
        matched_name = $matchedName
        matched_type = $matchedType
      }
    }
    $pattern = $null
    if ($element.TryGetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern, [ref]$pattern)) {
      $pattern.Select()
      return [pscustomobject]@{
        ok = $true
        backend = "uia"
        pattern = "SelectionItemPattern"
        process_id = $processId
        window_title = [string]$process.MainWindowTitle
        matched_name = $matchedName
        matched_type = $matchedType
      }
    }
  } catch {
    return [pscustomobject]@{ ok = $false; backend = "uia"; error = "uia_invoke_failed"; process_id = $processId; matched_name = $matchedName; matched_type = $matchedType; message = $_.Exception.Message }
  }
  return [pscustomobject]@{ ok = $false; backend = "uia"; error = "uia_supported_pattern_missing"; process_id = $processId; matched_name = $matchedName; matched_type = $matchedType }
}

function Resolve-XinjianCurrentUrl([int]$CdpPort) {
  $result = [ordered]@{
    ok = $false
    url = ""
    source = ""
    confidence = "none"
    reason = ""
    candidates = @()
  }
  $detector = Join-Path $PSScriptRoot "detect-ziniao-windows.ps1"
  if (!(Test-Path -LiteralPath $detector)) {
    $result.reason = "detector_missing"
    return [pscustomobject]$result
  }

  $raw = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $detector -Port $CdpPort -Json 2>&1)
  $detected = ConvertFrom-JsonText $raw
  if (!$detected -or !$detected.ok) {
    $result.reason = "detector_failed"
    return [pscustomobject]$result
  }

  $foregroundPid = Get-ForegroundProcessId
  $windows = @($detected.windows | Where-Object {
      $_.platform -eq "xinjian_erp" -and $_.page_url -and (Test-XinjianUrl ([string]$_.page_url))
    })
  $visible = @($windows | Where-Object { $_.source -in @("window_uia", "window_title") })
  $visibleCandidates = @($visible | Select-Object -First 8 | ForEach-Object {
      [ordered]@{
        source = $_.source
        process_id = $_.process_id
        title = $_.page_title
        url = $_.page_url
        is_foreground_process = ($foregroundPid -and $_.process_id -eq $foregroundPid)
      }
    })
  $result.candidates = @($visibleCandidates)

  $foreground = @($visible | Where-Object { $foregroundPid -and $_.process_id -eq $foregroundPid } | Select-Object -First 1)
  if ($foreground.Count -gt 0) {
    $result.ok = $true
    $result.url = [string]$foreground[0].page_url
    $result.source = [string]$foreground[0].source
    $result.confidence = "foreground_window_url"
    return [pscustomobject]$result
  }

  $uniqueVisibleUrls = @($visible | ForEach-Object { [string]$_.page_url } | Where-Object { $_ } | Sort-Object -Unique)
  if ($uniqueVisibleUrls.Count -eq 1) {
    $result.ok = $true
    $result.url = [string]$uniqueVisibleUrls[0]
    $result.source = "visible_window_url"
    $result.confidence = "single_visible_xinjian_window"
    return [pscustomobject]$result
  }

  $uniqueCdpUrls = @()
  try {
    $body = (Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:$CdpPort/json" -TimeoutSec 5).Content
    $parsedPages = $body | ConvertFrom-Json
    $pages = @($parsedPages | ForEach-Object { $_ })
    $uniqueCdpUrls = @($pages |
      Where-Object { $_.type -eq "page" -and (Test-XinjianUrl ([string]$_.url)) } |
      ForEach-Object { [string]$_.url } |
      Sort-Object -Unique)
  } catch {
    $uniqueCdpUrls = @()
  }
  if ($uniqueCdpUrls.Count -eq 1) {
    $result.ok = $true
    $result.url = [string]$uniqueCdpUrls[0]
    $result.source = "cdp_page_url"
    $result.confidence = "single_debuggable_xinjian_page"
    return [pscustomobject]$result
  }

  $knownCandidateUrls = @($result.candidates | ForEach-Object { [string]$_.url } | Where-Object { $_ })
  foreach ($cdpUrl in $uniqueCdpUrls) {
    if ($knownCandidateUrls -contains $cdpUrl) { continue }
    $result.candidates += [ordered]@{
      source = "cdp_page_url"
      process_id = $null
      title = ""
      url = $cdpUrl
      is_foreground_process = $false
    }
  }

  $result.reason = if ($uniqueVisibleUrls.Count -gt 1 -or $uniqueCdpUrls.Count -gt 1) { "ambiguous_xinjian_windows" } else { "no_xinjian_window" }
  return [pscustomobject]$result
}

function Get-SafetyMode([string]$Safety) {
  if ($Safety -like "confirmation_required_export*") { return "confirmation_required_export" }
  if ($Safety -like "confirmation_required*") { return "confirmation_required_write" }
  if ($Safety -in @("read_filter", "navigation", "view_setting", "account_menu", "opens_dialog_no_submit", "form_field")) { return "safe_execute_allowed" }
  return "dry_run_only_unknown_safety"
}

function Join-Codepoints([int[]]$Codes) {
  return -join ($Codes | ForEach-Object { [char]$_ })
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
    if ($locator.uia_name) { return "map_only_uia_locator" }
  }
  $name = [string]$Action.name
  $genericTabNames = @(
    (Join-Codepoints @(0x5E73, 0x53F0, 0x6807, 0x7B7E))
  )
  $genericRowNames = @(
    (Join-Codepoints @(0x884C, 0x5206, 0x6790)),
    (Join-Codepoints @(0x64CD, 0x4F5C))
  )
  if ($name -and ($type -in @("tab", "status_tab")) -and ($name -notin $genericTabNames)) { return "click_visible_action_text" }
  if ($name -and $type -eq "row_navigation" -and ($name -notin $genericRowNames)) { return "click_visible_action_text" }
  if ($name -and $type -eq "date_filter") { return "click_visible_filter_label_or_text" }
  if (!$locator) { return "no_locator" }
  return "best_effort_locator"
}

$requestedUrl = $Url
$urlDetection = $null
if (!$Url -and !$NoAutoDetectUrl) {
  $urlDetection = Resolve-XinjianCurrentUrlByScript -QueryIntent $Intent
  if ($urlDetection.ok -and $urlDetection.url) {
    $Url = [string]$urlDetection.url
  }
} elseif ($Url) {
  $urlDetection = Resolve-XinjianCurrentUrlByScript
}

$explicitUrlProvided = [bool]$requestedUrl
$effectivePort = Get-ResolvedPort -Detection $urlDetection -InputUrl $Url -ExplicitUrlProvided $explicitUrlProvided

$currentUrl = $Url
$currentTitle = Get-ResolvedTitle -Detection $urlDetection -InputUrl $Url
$currentPageKind = Get-XinjianPageKind $Url

$nonBusinessReason = Get-XinjianNonBusinessPageReason $Url
if ($nonBusinessReason) {
  $payload = [ordered]@{
    ok = $false
    mode = "non_business_xinjian_page"
    intent = $Intent
    url = $Url
    current_url = $currentUrl
    current_title = $currentTitle
    resolved_port = $effectivePort
    page_kind = $currentPageKind
    requested_url = $requestedUrl
    url_detection = $urlDetection
    ports = @($Port | Where-Object { $_ -gt 0 } | Sort-Object -Unique)
    reason = $nonBusinessReason
    next_action = $nonBusinessReason
  }
  if ($Json) { $payload | ConvertTo-Json -Depth 16 } else { Write-Host "Current Xinjian page is not a business page: $Url" }
  exit 1
}

$queryResult = Invoke-XinjianActionQuery -QueryIntent $Intent -QueryUrl $Url
$queryRaw = $queryResult.raw
$queryExit = $queryResult.exit_code
$query = $queryResult.parsed
if (!$query) {
  $payload = [ordered]@{
    ok = $false
    error = "query_output_parse_failed"
    mode = "query_output_parse_failed"
    intent = $Intent
    url = $Url
    current_url = $currentUrl
    current_title = $currentTitle
    resolved_port = $effectivePort
    page_kind = $currentPageKind
    requested_url = $requestedUrl
    url_detection = $urlDetection
    exit_code = $queryExit
    raw_output = ($queryRaw | Out-String).Trim()
    next_action = "repair_xinjian_action_query_output"
  }
  if ($Json) { $payload | ConvertTo-Json -Depth 8 } else { Write-Host $payload.error }
  exit 2
}

$matches = @($query.matches)
if (!$query.ok -or $matches.Count -eq 0) {
  $payload = [ordered]@{
    ok = $false
    mode = "no_match"
    intent = $Intent
    url = $Url
    current_url = $currentUrl
    current_title = $currentTitle
    resolved_port = $effectivePort
    page_kind = $currentPageKind
    requested_url = $requestedUrl
    url_detection = $urlDetection
    query = $query
    next_action = "capture_current_page_then_update_xinjian_ui_map"
  }
  if ($Json) { $payload | ConvertTo-Json -Depth 16 } else { Write-Host "No mapped Xinjian action matched." }
  exit 1
}

if ($CandidateIndex -lt 0 -or $CandidateIndex -ge $matches.Count) {
  $CandidateIndex = 0
}
$match = $matches[$CandidateIndex]
$action = $match.action
$safety = [string]$action.safety
$safetyMode = Get-SafetyMode $safety
$locatorStrategy = Get-LocatorStrategy $action
$requiresExport = ($safetyMode -eq "confirmation_required_export")
$requiresWrite = ($safetyMode -eq "confirmation_required_write")
$unknownSafety = ($safetyMode -eq "dry_run_only_unknown_safety")
$hasExplicitRowContext = ($RowIndex -gt 0 -or ![string]::IsNullOrWhiteSpace($RowText))
$actionHasRowContextBoundary = ($locatorStrategy -like "row_context_required*" -or [string]$action.type -in @("row_action", "row_navigation", "row_operation"))
$requiresRowContext = ($actionHasRowContextBoundary -and !$hasExplicitRowContext)
$requiresUiaLocator = ($locatorStrategy -eq "map_only_uia_locator")
$requiresPageContext = !$Url
$requiresCdpPort = !$effectivePort
$readOnlyCatalogEntry = ($locatorStrategy -eq "read_table_column_header")
$uiaCanExecute = $false
$uiaWindowProcessId = $null
$uiaEligible = !$unknownSafety -and !$requiresRowContext -and !$requiresPageContext -and !$readOnlyCatalogEntry -and !$requiresExport -and !$requiresWrite
if (($requiresCdpPort -or $requiresUiaLocator) -and $uiaEligible) {
  $uiaWindowProcessId = Get-UiaWindowProcessId -Detection $urlDetection -InputUrl $Url
  $uiaCanExecute = Test-UiaActionExecutable -Action $action -InputUrl $Url -Detection $urlDetection
}
$executionBackend = if ($requiresUiaLocator) { if ($uiaCanExecute) { "uia" } else { "none" } } elseif ($effectivePort) { "cdp" } elseif ($uiaCanExecute) { "uia" } else { "none" }
$canExecute = !$unknownSafety -and !$requiresRowContext -and !$requiresPageContext -and (!$requiresCdpPort -or $uiaCanExecute) -and (!$requiresUiaLocator -or $uiaCanExecute) -and !$readOnlyCatalogEntry -and (!$requiresExport -or $AllowExport -or $AllowWrite) -and (!$requiresWrite -or $AllowWrite)

$plan = [ordered]@{
  intent = $Intent
  url = $Url
  current_url = $currentUrl
  current_title = $currentTitle
  page_kind = $currentPageKind
  requested_url = $requestedUrl
  url_detection = $urlDetection
  ports = @($Port | Where-Object { $_ -gt 0 } | Sort-Object -Unique)
  resolved_port = $effectivePort
  execution_backend = $executionBackend
  uia_fallback_available = [bool]$uiaCanExecute
  uia_window_process_id = $uiaWindowProcessId
  candidate_index = $CandidateIndex
  row_context = [ordered]@{
    required = [bool]$actionHasRowContextBoundary
    provided = [bool]$hasExplicitRowContext
    row_index = if ($RowIndex -gt 0) { $RowIndex } else { $null }
    row_text = if (![string]::IsNullOrWhiteSpace($RowText)) { "[provided]" } else { $null }
  }
  page_id = $match.page_id
  page_name = $match.page_name
  score = $match.score
  rank = $match.rank
  action = $action
  safety_mode = $safetyMode
  locator_strategy = $locatorStrategy
  execute_requested = [bool]$Execute
  can_execute = [bool]$canExecute
  safety_note = if ($readOnlyCatalogEntry) {
    "Read-only table column memory. No click is needed; use the matched page/column to locate or interpret visible data."
  } elseif ($requiresPageContext -and $requiresWrite) {
    "Write/delete/save/submit-like action and no current Xinjian URL was resolved. Pass -Url or focus the target Xinjian window, then use -Execute -AllowWrite only after explicit confirmation."
  } elseif ($requiresPageContext -and $requiresExport) {
    "Export/download action and no current Xinjian URL was resolved. Pass -Url or focus the target Xinjian window, then use -Execute -AllowExport only after explicit confirmation."
  } elseif ($requiresPageContext) {
    "No current Xinjian URL was resolved. Dry-run only; bring the target Xinjian window to the foreground or pass -Url to execute."
  } elseif ($requiresRowContext) {
    "Row-level action needs an explicit row context. Pass -RowIndex <1-based row number> or -RowText <text visible in the target row>; refusing to blindly click a row."
  } elseif ($actionHasRowContextBoundary -and $hasExplicitRowContext -and ($requiresWrite -or $requiresExport)) {
    "Row-level write/export action has explicit row context. Dry-run by default; pass -Execute with the required AllowWrite/AllowExport switch only after explicit user confirmation."
  } elseif ($actionHasRowContextBoundary -and $hasExplicitRowContext) {
    "Row-level action has explicit row context and can execute against that row with -Execute."
  } elseif ($requiresWrite -and $requiresCdpPort) {
    "Write/delete/save/submit-like action and no controllable Xinjian CDP/UIA target was resolved. Dry-run only; focus/pass the target page and use -Execute -AllowWrite only after explicit confirmation."
  } elseif ($requiresExport -and $requiresCdpPort) {
    "Export/download action and no controllable Xinjian CDP/UIA target was resolved. Dry-run only; focus/pass the target page and use -Execute -AllowExport only after explicit confirmation."
  } elseif ($requiresWrite) {
    "Write/delete/save/submit-like action. Dry-run by default; pass -Execute -AllowWrite only after explicit user confirmation."
  } elseif ($requiresExport) {
    "Export/download action. Dry-run by default; pass -Execute -AllowExport only after explicit user confirmation."
  } elseif ($unknownSafety) {
    "Unknown safety. Dry-run only until this action is manually classified."
  } elseif ($requiresUiaLocator -and $uiaCanExecute) {
    "Mapped UIA action can run through Windows UI Automation on the already-open window without mouse movement."
  } elseif ($requiresUiaLocator) {
    "Mapped UIA action needs a matching already-open Xinjian window control. Dry-run only; no matching UIA control was resolved."
  } elseif ($requiresCdpPort -and $uiaCanExecute) {
    "No debuggable Xinjian CDP port was resolved, but this safe non-write action can run through Windows UI Automation on the already-open window without mouse movement."
  } elseif ($requiresCdpPort) {
    "No debuggable Xinjian CDP port was resolved. Dry-run only; open or log in to Xinjian in a Chrome/Edge/Ziniao window with DevTools enabled."
  } else {
    "Safe non-write action can be executed with -Execute."
  }
}

if (!$Execute) {
  $payload = [ordered]@{
    ok = $true
    mode = "dry_run"
    intent = $Intent
    url = $Url
    current_url = $currentUrl
    current_title = $currentTitle
    resolved_port = $effectivePort
    page_kind = $currentPageKind
    execution_backend = $executionBackend
    plan = $plan
    query_versions = [ordered]@{
      map = $query.map_version
      auto_map = $query.auto_map_version
      overlay_map = $query.overlay_map_version
      dialog_map = $query.dialog_map_version
      row_action_map = $query.row_action_map_version
    }
    alternatives = @($matches | Select-Object -Skip 1 -First 4)
  }
  if ($Json) {
    $payload | ConvertTo-Json -Depth 20
  } else {
    Write-Host ("DRY-RUN {0} / {1} -> {2} ({3})" -f $match.page_name, $action.name, $action.purpose, $safetyMode)
  }
  exit 0
}

if (!$canExecute) {
  $payload = [ordered]@{
    ok = $false
    mode = "blocked_by_safety"
    intent = $Intent
    url = $Url
    current_url = $currentUrl
    current_title = $currentTitle
    resolved_port = $effectivePort
    page_kind = $currentPageKind
    execution_backend = $executionBackend
    plan = $plan
    next_action = if ($readOnlyCatalogEntry) { "use_table_column_memory_for_read_only_planning" } elseif ($requiresRowContext) { "provide_row_context_or_capture_row_action_buttons" } elseif ($requiresPageContext -and $requiresWrite) { "focus_target_xinjian_window_or_pass_url_then_confirm_write" } elseif ($requiresPageContext -and $requiresExport) { "focus_target_xinjian_window_or_pass_url_then_confirm_export" } elseif ($requiresPageContext) { "focus_target_xinjian_window_or_pass_url" } elseif ($requiresWrite -and $requiresCdpPort) { "focus_target_xinjian_window_or_pass_url_then_confirm_write" } elseif ($requiresExport -and $requiresCdpPort) { "focus_target_xinjian_window_or_pass_url_then_confirm_export" } elseif ($requiresWrite) { "rerun_with_execute_allow_write_after_explicit_confirmation" } elseif ($requiresExport) { "rerun_with_execute_allow_export_after_explicit_confirmation" } elseif ($requiresUiaLocator) { "capture_or_focus_matching_uia_xinjian_control" } elseif ($requiresCdpPort) { "open_or_login_debuggable_xinjian_browser_or_use_mapped_uia_window" } else { "manual_review_action_safety" }
  }
  if ($Json) {
    $payload | ConvertTo-Json -Depth 20
  } else {
    Write-Host ("Blocked by safety: {0}" -f $plan.safety_note)
  }
  exit 3
}

if ($executionBackend -eq "uia") {
  $result = Invoke-XinjianUiaAction -Action $action -InputUrl $Url -Detection $urlDetection
  $payload = [ordered]@{
    ok = [bool]$result.ok
    mode = "executed"
    execution_backend = "uia"
    intent = $Intent
    url = $Url
    current_url = $currentUrl
    current_title = $currentTitle
    resolved_port = $effectivePort
    page_kind = $currentPageKind
    plan = $plan
    result = $result
  }
  if ($Json) {
    $payload | ConvertTo-Json -Depth 20
  } else {
    if ($result.ok) {
      Write-Host ("Executed Xinjian action through UIA: {0}" -f $action.name)
    } else {
      Write-Host ("Xinjian UIA action execution failed: {0}" -f $result.error)
    }
  }
  if ($result.ok) { exit 0 }
  exit 4
}

$node = Get-Command node -ErrorAction SilentlyContinue
if (!$node) {
  $payload = [ordered]@{
    ok = $false
    error = "node_missing"
    mode = "node_missing"
    intent = $Intent
    url = $Url
    current_url = $currentUrl
    current_title = $currentTitle
    resolved_port = $effectivePort
    page_kind = $currentPageKind
    message = "Node.js is required for CDP action execution."
    plan = $plan
  }
  if ($Json) { $payload | ConvertTo-Json -Depth 16 } else { Write-Host $payload.message }
  exit 2
}

$helper = Join-Path $PSScriptRoot "invoke-xinjian-ui-action-cdp.mjs"
if (!(Test-Path -LiteralPath $helper)) {
  $payload = [ordered]@{
    ok = $false
    error = "invoke_helper_missing"
    mode = "invoke_helper_missing"
    intent = $Intent
    url = $Url
    current_url = $currentUrl
    current_title = $currentTitle
    resolved_port = $effectivePort
    page_kind = $currentPageKind
    path = $helper
    plan = $plan
  }
  if ($Json) { $payload | ConvertTo-Json -Depth 16 } else { Write-Host "Missing helper: $helper" }
  exit 2
}

$stateDir = Join-Path $root ".ziniao-ops\xinjian-action-runner"
New-Item -ItemType Directory -Force -Path $stateDir | Out-Null
$actionPath = Join-Path $stateDir ("action-{0}.json" -f ([guid]::NewGuid().ToString("N")))
$actionForRun = $action | ConvertTo-Json -Depth 14 | ConvertFrom-Json
$actionForRun | Add-Member -NotePropertyName "runtime_intent" -NotePropertyValue $Intent -Force
if ($RowIndex -gt 0) {
  $actionForRun | Add-Member -NotePropertyName "runtime_row_index" -NotePropertyValue $RowIndex -Force
}
if (![string]::IsNullOrWhiteSpace($RowText)) {
  $actionForRun | Add-Member -NotePropertyName "runtime_row_text" -NotePropertyValue $RowText -Force
}
$actionForRun | ConvertTo-Json -Depth 14 | Set-Content -LiteralPath $actionPath -Encoding UTF8

$argsList = @($helper, "--port", [string]$effectivePort, "--action-file", $actionPath)
if ($Url) { $argsList += @("--match-url", $Url) }
if ($AllowWrite) { $argsList += "--allow-write" }
if ($AllowExport) { $argsList += "--allow-export" }
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
  $raw = @(& node @argsList 2>&1)
  $code = $LASTEXITCODE
} finally {
  $ErrorActionPreference = $previousErrorActionPreference
}
Remove-Item -LiteralPath $actionPath -ErrorAction SilentlyContinue
$result = ConvertFrom-JsonText $raw
if (!$result) {
  $result = [pscustomobject]@{
    ok = $false
    error = "invoke_output_parse_failed"
    exit_code = $code
    raw_output = ($raw | Out-String).Trim()
  }
}

$payload = [ordered]@{
  ok = [bool]$result.ok
  mode = "executed"
  intent = $Intent
  url = $Url
  current_url = $currentUrl
  current_title = $currentTitle
  resolved_port = $effectivePort
  page_kind = $currentPageKind
  execution_backend = "cdp"
  plan = $plan
  result = $result
}
if ($Json) {
  $payload | ConvertTo-Json -Depth 20
} else {
  if ($result.ok) {
    Write-Host ("Executed Xinjian action: {0}" -f $action.name)
  } else {
    Write-Host ("Xinjian action execution failed: {0}" -f $result.error)
  }
}
exit $code
