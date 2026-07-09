[CmdletBinding(PositionalBinding = $false)]
param(
  [int]$Port = 9339,
  [string]$Origin = "https://erp.xinjianerp.com",
  [string]$CatalogPath = "",
  [string]$OutputJson = "",
  [string]$OutputMd = "",
  [string]$CaptureDir = "",
  [int]$MaxPages = 0,
  [int]$WaitMs = 0,
  [string]$RouteRegex = ".",
  [switch]$UseExistingCaptures,
  [switch]$Json
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path

if (!$CatalogPath) { $CatalogPath = Join-Path $root "references\xinjian-ui-action-catalog.json" }
if (!$OutputJson) { $OutputJson = Join-Path $root "references\xinjian-ui-live-button-coverage.json" }
if (!$OutputMd) { $OutputMd = Join-Path $root "references\xinjian-ui-live-button-coverage.md" }
if (!$CaptureDir) { $CaptureDir = Join-Path $root ".ziniao-ops\xinjian-live-button-audit" }
New-Item -ItemType Directory -Force -Path $CaptureDir | Out-Null

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

function Get-RouteKey([string]$Value) {
  if (!$Value) { return "" }
  $text = [string]$Value
  if ($text -match "^[A-Za-z][A-Za-z0-9+.-]*://") {
    try { $text = ([uri]$text).AbsolutePath } catch {}
  }
  if (!$text.StartsWith("/")) { $text = "/" + $text }
  $text = $text -replace "/+", "/"
  if ($text.Length -gt 1) { $text = $text.TrimEnd("/") }
  return $text
}

function Test-RestrictedTerminalRoute([string]$Value) {
  return ((Get-RouteKey $Value).ToLowerInvariant() -eq "/index/noaccess")
}

function Get-SafeSlug([string]$Value) {
  $text = (Get-RouteKey $Value).Trim("/")
  if (!$text) { $text = "root" }
  $text = $text -replace "[^A-Za-z0-9._-]+", "_"
  if ($text.Length -gt 90) { $text = $text.Substring(0, 90) }
  return $text
}

function Get-LatestCapturePath([string]$Dir, [string]$Route) {
  if (!(Test-Path -LiteralPath $Dir)) { return "" }
  $slug = Get-SafeSlug $Route
  $item = Get-ChildItem -LiteralPath $Dir -Filter "*-$slug.json" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
  if ($item) { return $item.FullName }
  return ""
}

function Normalize-Text([string]$Value) {
  return ([string]$Value) `
    -replace "[\uE000-\uF8FF]", " " `
    -replace "\s+", " "
}

function Normalize-Key([string]$Value) {
  $text = (Normalize-Text $Value).Trim().ToLowerInvariant()
  $text = $text -replace "\s+", ""
  $text = $text -replace "[:,.!?()\[\]]", ""
  return $text
}

function Test-OperationColumn([string]$Type, [string]$Name) {
  $text = (Normalize-Text $Name).Trim()
  if ($Type -ne "table_column") { return $false }
  if ($text.Length -ne 2) { return $false }
  return (([int][char]$text[0]) -eq 25805 -and ([int][char]$text[1]) -eq 20316)
}

function Test-PrivateLike([string]$Value) {
  $text = (Normalize-Text $Value).Trim()
  if (!$text) { return $false }
  return ($text -match "@" -or
    $text -match "\b\d{7,}\b" -or
    $text -match "\b[A-Za-z][A-Za-z0-9 ._-]{1,50}-(?:my|th|id|sg|ph|vn)-(?:sp|tt|la)\b" -or
    $text -match "(?:token|secret|password|passwd|cookie|session|auth)\s*[:=]")
}

function Test-TransientControl($Control) {
  $selector = [string]$Control.selector
  $classes = ""
  if ($Control.classes -is [array]) { $classes = ($Control.classes -join " ") } else { $classes = [string]$Control.classes }
  $marker = "$selector $classes"
  return ($marker -match "(?:^|[ .#>])(?:el-picker-panel|el-date-picker|el-date-range-picker|el-select-dropdown|el-cascader-panel|el-dropdown-menu|el-popper|el-tooltip__popper|el-autocomplete-suggestion|el-dialog|el-drawer|el-message-box)(?:\b|[ .#>_-])")
}

function Test-PaginationNoise($Control, [string]$Name) {
  $selector = [string]$Control.selector
  $classes = ""
  if ($Control.classes -is [array]) { $classes = ($Control.classes -join " ") } else { $classes = [string]$Control.classes }
  $marker = "$selector $classes"
  $compact = (Normalize-Key $Name)
  return ($marker -match "pagination|el-pagination|page-down" -or
    $compact -match "^(上一页|下一页|前往|页|条/页|\d+条/页|\d+)$")
}

function Test-AppShellControl($Control, [string]$Name) {
  $selector = [string]$Control.selector
  $classes = ""
  if ($Control.classes -is [array]) { $classes = ($Control.classes -join " ") } else { $classes = [string]$Control.classes }
  $marker = "$selector $classes"
  $compact = Normalize-Key $Name
  return ($marker -match "rightPanel-container|rightPanel-items|drawer-container|avatar-container|avatar-wrapper" -or
    ($marker -match "el-scrollbar\.theme-light|sidebar-container|scrollbar-wrapper\.el-scrollbar__wrap" -and $marker -match "ul\.el-menu") -or
    $marker -match "bjs-powered-by" -or
    (Normalize-Key $Name) -eq "poweredbybpmnio" -or
    $compact -eq "用户菜单")
}

function Get-ControlName($Control) {
  $type = [string]$Control.type
  $name = if ($type -eq "input" -or $type -eq "select") {
    if ($Control.placeholder) { [string]$Control.placeholder } else { [string]$Control.name }
  } else {
    [string]$Control.name
  }
  $name = (Normalize-Text $name).Trim()
  if ($type -eq "tab") { $name = ($name -replace "\s+\d+$", "").Trim() }
  if ($type -eq "menu") { $name = ($name -replace "\(\d+\)$", "").Trim() }
  return $name
}

function Convert-ControlType([string]$Type, [string]$Tag) {
  if ($Tag -eq "th" -or $Type -eq "columnheader") { return "table_column" }
  if ($Type -in @("button", "input", "select", "tab", "menu", "link", "checkbox")) { return $Type }
  return $Type
}

function Get-ObservedControls($Capture) {
  $items = @()
  foreach ($control in @($Capture.controls)) {
    if (Test-TransientControl $control) { continue }
    $type = Convert-ControlType ([string]$control.type) ([string]$control.tag)
    if ($type -notin @("button", "input", "select", "tab", "menu", "link", "checkbox", "table_column")) { continue }
    $name = Get-ControlName $control
    if (!$name) { continue }
    if ($name.Length -gt 80) { continue }
    if (Test-PrivateLike $name) { continue }
    if (Test-PaginationNoise $control $name) { continue }
    if (Test-AppShellControl $control $name) { continue }
    if (Test-OperationColumn $type $name) { continue }
    if ($type -eq "select" -and $name -eq "请选择") {
      # Generic select placeholders are represented by overlay-trigger memory.
      # Keep named selects; otherwise these cause false missing-control noise.
      continue
    }
    $key = "{0}|{1}" -f $type, (Normalize-Key $name)
    $items += [pscustomobject]@{
      type = $type
      name = $name
      key = $key
      selector = [string]$control.selector
      disabled = [bool]$control.disabled
    }
  }
  $seen = @{}
  $result = @()
  foreach ($item in $items) {
    if ($seen[$item.key]) { continue }
    $seen[$item.key] = $true
    $result += $item
  }
  return $result
}

function Add-KnownKey([hashtable]$Map, [string]$Type, [string]$Name) {
  $keyText = Normalize-Key $Name
  if (!$keyText) { return }
  $Map["$Type|$keyText"] = $true
  $Map["any|$keyText"] = $true
}

function Get-KnownKeys($Page, $Catalog) {
  $known = @{}
  foreach ($action in @($Page.actions)) {
    $type = [string]$action.type
    $normalizedType = switch ($type) {
      "filter_input" { "input"; break }
      "form_input" { "input"; break }
      "filter_dropdown" { "select"; break }
      "form_dropdown" { "select"; break }
      "table_column" { "table_column"; break }
      "navigation" { "link"; break }
      default { $type; break }
    }
    Add-KnownKey $known $normalizedType ([string]$action.name)
    Add-KnownKey $known "any" ([string]$action.name)
    foreach ($alias in @($action.aliases)) { Add-KnownKey $known $normalizedType ([string]$alias) }
    if ($action.context) { Add-KnownKey $known "any" ([string]$action.context) }
    $locator = $action.locator
    if ($locator) {
      foreach ($field in @("dom_text", "dom_placeholder", "table_column", "tab_text", "trigger_text", "button_text", "row_action_text")) {
        if ($locator.PSObject.Properties.Match($field).Count) {
          Add-KnownKey $known $normalizedType ([string]$locator.$field)
          Add-KnownKey $known "any" ([string]$locator.$field)
        }
      }
      foreach ($field in @("dom_placeholders", "tab_texts")) {
        if ($locator.PSObject.Properties.Match($field).Count) {
          foreach ($value in @($locator.$field)) {
            Add-KnownKey $known $normalizedType ([string]$value)
            Add-KnownKey $known "any" ([string]$value)
          }
        }
      }
    }
  }
  if (@($Page.actions | Where-Object { ([string]$_.type) -in @("row_action", "row_navigation", "row_operation") }).Count -gt 0) {
    Add-KnownKey $known "table_column" "操作"
    Add-KnownKey $known "any" "操作"
  }
  foreach ($action in @($Catalog.global_actions)) {
    Add-KnownKey $known "any" ([string]$action.name)
    foreach ($alias in @($action.aliases)) { Add-KnownKey $known "any" ([string]$alias) }
  }
  return $known
}

function Test-ControlKnown($Control, [hashtable]$Known) {
  $nameKey = Normalize-Key $Control.name
  if (!$nameKey) { return $true }
  if (Test-OperationColumn ([string]$Control.type) ([string]$Control.name)) { return $true }
  if ($Known["$($Control.type)|$nameKey"]) { return $true }
  if ($Known["any|$nameKey"]) { return $true }
  if ($Control.type -eq "button" -and $Known["link|$nameKey"]) { return $true }
  if ($Control.type -eq "link" -and $Known["navigation|$nameKey"]) { return $true }
  if ($Control.type -eq "menu" -and $Known["button|$nameKey"]) { return $true }
  return $false
}

if (!(Test-Path -LiteralPath $CatalogPath)) {
  $payload = [ordered]@{ ok = $false; error = "catalog_missing"; path = $CatalogPath }
  if ($Json) { $payload | ConvertTo-Json -Depth 8 } else { Write-Host "Missing catalog: $CatalogPath" }
  exit 2
}

$cdpAvailable = Test-CdpPort -CdpPort $Port
if (!$cdpAvailable -and !$UseExistingCaptures) {
  $payload = [ordered]@{ ok = $false; error = "cdp_port_not_reachable"; port = $Port }
  if ($Json) { $payload | ConvertTo-Json -Depth 8 } else { Write-Host "CDP port not reachable: $Port" }
  exit 2
}

$catalog = Get-Content -LiteralPath $CatalogPath -Raw -Encoding UTF8 | ConvertFrom-Json
$pages = @($catalog.pages | Where-Object { $_.route -and ([string]$_.route) -match $RouteRegex } | Sort-Object route -Unique)
if ($MaxPages -gt 0) { $pages = @($pages | Select-Object -First $MaxPages) }

$results = @()
foreach ($page in $pages) {
  $route = Get-RouteKey ([string]$page.route)
  $url = ([uri]::new([uri]$Origin, $route)).AbsoluteUri
  $capturePath = Join-Path $CaptureDir ("{0}-{1}.json" -f (Get-Date -Format "yyyyMMdd-HHmmss"), (Get-SafeSlug $route))
  $capture = $null
  if ($UseExistingCaptures) {
    $existingCapturePath = Get-LatestCapturePath -Dir $CaptureDir -Route $route
    if ($existingCapturePath) {
      try {
        $capture = Get-Content -LiteralPath $existingCapturePath -Raw -Encoding UTF8 | ConvertFrom-Json
        $capturePath = $existingCapturePath
      } catch {
        $capture = $null
      }
    }
  }
  if (!$capture -and $cdpAvailable) {
    $raw = @()
    try {
      $raw = @(& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "capture-xinjian-dom-map.ps1") -Port $Port -Url $url -OutputPath $capturePath -Json 2>&1)
    } catch {
      $raw = @($_.Exception.Message)
    }
    $capture = ConvertFrom-JsonText $raw
  }
  if ($WaitMs -gt 0) { Start-Sleep -Milliseconds $WaitMs }

  if (!$capture -or !$capture.ok) {
    $results += [pscustomobject]@{
      page_id = [string]$page.id
      page_name = [string]$page.name
      route = $route
      status = "capture_failed"
      captured_path = ""
      observed_controls = 0
      matched_controls = 0
      missing_controls = @()
      error = if ($capture) { [string]$capture.error } elseif (!$cdpAvailable -and $UseExistingCaptures) { "existing_capture_missing" } else { "capture_output_parse_failed" }
      capture_path = $capturePath
    }
    continue
  }

  $capturedPath = Get-RouteKey ([string]$capture.page.path)
  $status = if ($capture.page.has_password_input) {
    "login"
  } elseif ($capturedPath -eq "/index/noaccess") {
    if (Test-RestrictedTerminalRoute $route) { "restricted_terminal" } else { "noaccess" }
  } elseif ($capturedPath.ToLowerInvariant() -ne $route.ToLowerInvariant()) {
    "redirected"
  } else {
    "captured"
  }

  $observed = @()
  if ($status -eq "captured") { $observed = @(Get-ObservedControls $capture) }
  $known = Get-KnownKeys -Page $page -Catalog $catalog
  $missing = @()
  $matchedCount = 0
  foreach ($control in $observed) {
    if (Test-ControlKnown $control $known) {
      $matchedCount += 1
    } else {
      $missing += [pscustomobject]@{
        type = $control.type
        name = $control.name
        selector = $control.selector
      }
    }
  }

  $results += [pscustomobject]@{
    page_id = [string]$page.id
    page_name = [string]$page.name
    route = $route
    status = $status
    captured_path = $capturedPath
    observed_controls = $observed.Count
    matched_controls = $matchedCount
    missing_controls = @($missing)
    error = ""
    capture_path = [string]$capture.output_path
  }
}

$missingRows = @($results | ForEach-Object {
  $pageResult = $_
  foreach ($missing in @($pageResult.missing_controls)) {
    [pscustomobject]@{
      route = $pageResult.route
      page_name = $pageResult.page_name
      type = $missing.type
      name = $missing.name
      selector = $missing.selector
    }
  }
})

$statusCounts = [ordered]@{}
foreach ($group in @($results | Group-Object status)) { $statusCounts[[string]$group.Name] = [int]$group.Count }
$missingTypeCounts = [ordered]@{}
foreach ($group in @($missingRows | Group-Object type)) { $missingTypeCounts[[string]$group.Name] = [int]$group.Count }

$payload = [ordered]@{
  version = "2026-07-09"
  system = "xinjian_erp"
  source = "live_cdp_dom_vs_action_catalog"
  generated_at = (Get-Date).ToUniversalTime().ToString("o")
  policy = [ordered]@{
    note = "This report stores only sanitized route, page, control type/name, selector, and coverage status. It does not store cookies, tokens, storage values, input values, table row values, or private business values."
    comparison_scope = "Visible non-transient controls from live route-scoped CDP DOM capture compared against xinjian-ui-action-catalog page/global action names, aliases, context, and locator labels."
  }
  totals = [ordered]@{
    pages_selected = $pages.Count
    pages_captured = @($results | Where-Object { $_.status -eq "captured" }).Count
    pages_redirected = @($results | Where-Object { $_.status -eq "redirected" }).Count
    pages_noaccess = @($results | Where-Object { $_.status -eq "noaccess" }).Count
    pages_restricted_terminal = @($results | Where-Object { $_.status -eq "restricted_terminal" }).Count
    pages_login = @($results | Where-Object { $_.status -eq "login" }).Count
    pages_failed = @($results | Where-Object { $_.status -eq "capture_failed" }).Count
    observed_controls = [int](($results | Measure-Object -Property observed_controls -Sum).Sum)
    matched_controls = [int](($results | Measure-Object -Property matched_controls -Sum).Sum)
    missing_controls = $missingRows.Count
    pages_with_missing_controls = @($results | Where-Object { @($_.missing_controls).Count -gt 0 }).Count
    status_counts = $statusCounts
    missing_type_counts = $missingTypeCounts
  }
  recent_missing_controls = @($missingRows | Select-Object -First 80)
  pages = @($results)
}

$payload | ConvertTo-Json -Depth 18 | Set-Content -LiteralPath $OutputJson -Encoding UTF8

$lines = @()
$lines += "# Xinjian Live Button Coverage Audit"
$lines += ""
$lines += ("Generated at: {0}" -f $payload.generated_at)
$lines += ""
$lines += "This report compares live route-scoped CDP DOM controls against the merged Xinjian action catalog. It stores sanitized control labels/selectors only; it does not store cookies, tokens, storage values, input values, table row values, or private business values."
$lines += ""
$lines += "## Totals"
$lines += ""
$lines += ("- Pages selected: {0}" -f $payload.totals.pages_selected)
$lines += ("- Pages captured: {0}" -f $payload.totals.pages_captured)
$lines += ("- Observed controls: {0}" -f $payload.totals.observed_controls)
$lines += ("- Matched controls: {0}" -f $payload.totals.matched_controls)
$lines += ("- Missing controls: {0}" -f $payload.totals.missing_controls)
$lines += ("- Pages with missing controls: {0}" -f $payload.totals.pages_with_missing_controls)
$lines += ("- Redirected/no-access/restricted-terminal/login/failed pages: {0}/{1}/{2}/{3}/{4}" -f $payload.totals.pages_redirected, $payload.totals.pages_noaccess, $payload.totals.pages_restricted_terminal, $payload.totals.pages_login, $payload.totals.pages_failed)
if ($missingRows.Count -gt 0) {
  $lines += ""
  $lines += "## Missing Controls"
  $lines += ""
  $lines += "| Route | Page | Type | Control |"
  $lines += "| --- | --- | --- | --- |"
  foreach ($item in @($missingRows | Select-Object -First 80)) {
    $lines += ("| {0} | {1} | {2} | {3} |" -f $item.route, $item.page_name, $item.type, $item.name)
  }
} else {
  $lines += ""
  $lines += "## Missing Controls"
  $lines += ""
  $lines += "No missing live controls were found in the captured route-scoped audit scope."
}
$lines -join [Environment]::NewLine | Set-Content -LiteralPath $OutputMd -Encoding UTF8

if ($Json) {
  $payload | ConvertTo-Json -Depth 18
} else {
  Write-Host ("Audited {0} Xinjian pages: {1} observed controls, {2} missing." -f $payload.totals.pages_selected, $payload.totals.observed_controls, $payload.totals.missing_controls)
  Write-Host ("Report: {0}" -f $OutputMd)
}

if ($payload.totals.pages_failed -gt 0) { exit 1 }
