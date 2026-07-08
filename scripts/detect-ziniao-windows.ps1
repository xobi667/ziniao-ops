[CmdletBinding(PositionalBinding = $false)]
param(
  [int[]]$Port = @(),
  [switch]$ZiniaoOnly,
  [switch]$IncludeWebSocketUrl,
  [switch]$Json
)

$ErrorActionPreference = "Stop"

# Read-only discovery of already-open browser windows. This script never
# navigates, clicks, types, or reads cookies/localStorage/tokens.
$KnownPageRules = @(
  @{ platform = "shopee";      page_kind = "seller_center"; url_pattern = "seller\.shopee\.|banhang\.shopee\."; title_pattern = "Shopee|\u867e\u76ae|\u5356\u5bb6\u4e2d\u5fc3" },
  @{ platform = "tiktok";      page_kind = "seller_center"; url_pattern = "seller-[a-z]+\.tiktok\.com|shop\.tiktok\.com"; title_pattern = "TikTok|Tokopedia|Seller Center" },
  @{ platform = "lazada";      page_kind = "seller_center"; url_pattern = "sellercenter\.lazada\."; title_pattern = "Lazada|Seller Center" },
  @{ platform = "xinjian_erp"; page_kind = "erp";           url_pattern = "erp\.xinjianerp\.com"; title_pattern = "\u5fc3\u8230|\u8fbe\u4eba\u516c\u6d77|[Xx]injian(?:\s*ERP)?|HighSeas.*[Xx]injian|[Xx]injian.*HighSeas" }
)

function Get-KnownPageMatch([string]$Url, [string]$Title = "") {
  foreach ($rule in $KnownPageRules) {
    if ($Url -and $Url -match $rule["url_pattern"]) {
      return [pscustomobject]@{
        platform = [string]$rule["platform"]
        page_kind = [string]$rule["page_kind"]
        confidence = "url_host"
      }
    }
  }
  foreach ($rule in $KnownPageRules) {
    if ($Title -and $Title -match $rule["title_pattern"]) {
      return [pscustomobject]@{
        platform = [string]$rule["platform"]
        page_kind = [string]$rule["page_kind"]
        confidence = "window_title"
      }
    }
  }
  return [pscustomobject]@{ platform = "unknown"; page_kind = "unknown"; confidence = "none" }
}

function Get-VisibleBrowserWindows {
  param([switch]$ZiniaoOnly)

  $names = @("ziniaobrowser")
  if (!$ZiniaoOnly) {
    $names += @("chrome", "msedge")
  }
  $rows = @()
  foreach ($name in $names) {
    Get-Process -Name $name -ErrorAction SilentlyContinue |
      Where-Object { $_.MainWindowHandle -ne 0 -and [string]$_.MainWindowTitle } |
      ForEach-Object {
        $processName = $_.ProcessName + ".exe"
        $rows += [pscustomobject]@{
          process_id = $_.Id
          process_name = $processName
          is_ziniao = ($processName -ieq "ziniaobrowser.exe")
          page_title = [string]$_.MainWindowTitle
        }
      }
  }
  return @($rows | Sort-Object process_id -Unique)
}

function Get-DebugBrowserPorts {
  param(
    [int[]]$ExplicitPort = @(),
    [switch]$ZiniaoOnly
  )

  if ($ExplicitPort -and $ExplicitPort.Count -gt 0) {
    return @($ExplicitPort | Sort-Object -Unique | ForEach-Object {
      [pscustomobject]@{
        port = [int]$_
        process_id = $null
        process_name = "explicit"
        is_ziniao = $false
      }
    })
  }

  $names = @("ziniaobrowser.exe")
  if (!$ZiniaoOnly) {
    $names += @("chrome.exe", "msedge.exe")
  }
  $names = @($names | ForEach-Object { $_.ToLowerInvariant() })

  $rows = @()
  Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object { $names -contains ([string]$_.Name).ToLowerInvariant() } |
    ForEach-Object {
      $cmd = [string]$_.CommandLine
      foreach ($match in [regex]::Matches($cmd, "--remote-debugging-port=(\d+)")) {
        $processName = [string]$_.Name
        $rows += [pscustomobject]@{
          port = [int]$match.Groups[1].Value
          process_id = $_.ProcessId
          process_name = $processName
          is_ziniao = ($processName -ieq "ziniaobrowser.exe")
        }
      }
    }

  return @($rows |
    Sort-Object @{ Expression = "port"; Descending = $false }, @{ Expression = "is_ziniao"; Descending = $true } |
    Group-Object port |
    ForEach-Object { $_.Group | Select-Object -First 1 })
}

function Test-CdpPort([int]$CdpPort) {
  try {
    Invoke-RestMethod -Uri "http://127.0.0.1:$CdpPort/json/version" -TimeoutSec 3 | Out-Null
    return $true
  } catch {
    return $false
  }
}

function Get-CdpPages([int]$CdpPort) {
  try {
    return @(Invoke-RestMethod -Uri "http://127.0.0.1:$CdpPort/json" -TimeoutSec 5)
  } catch {
    return @()
  }
}

$scanStarted = Get-Date
$debugPorts = @(Get-DebugBrowserPorts -ExplicitPort $Port -ZiniaoOnly:$ZiniaoOnly)
$visibleBrowserWindows = @(Get-VisibleBrowserWindows -ZiniaoOnly:$ZiniaoOnly)

$windows = @()
$cdpWindowKeys = [System.Collections.Generic.HashSet[string]]::new()
foreach ($portInfo in $debugPorts) {
  $reachable = Test-CdpPort -CdpPort $portInfo.port
  if (!$reachable) {
    $windows += [pscustomobject]@{
      port = $portInfo.port
      process_name = $portInfo.process_name
      process_id = $portInfo.process_id
      is_ziniao = $portInfo.is_ziniao
      reachable = $false
      page_url = $null
      page_title = $null
      platform = $null
      page_kind = $null
      login_signal = "cdp_port_not_reachable"
    }
    continue
  }

  $pages = @(Get-CdpPages -CdpPort $portInfo.port |
    Where-Object { $_.type -eq "page" -and [string]$_.url -notmatch "^chrome-extension://" })
  if ($pages.Count -eq 0) {
    $windows += [pscustomobject]@{
      port = $portInfo.port
      process_name = $portInfo.process_name
      process_id = $portInfo.process_id
      is_ziniao = $portInfo.is_ziniao
      reachable = $true
      page_url = $null
      page_title = $null
      platform = $null
      page_kind = $null
      login_signal = "no_page"
    }
    continue
  }

  foreach ($page in $pages) {
    $match = Get-KnownPageMatch -Url ([string]$page.url) -Title ([string]$page.title)
    [void]$cdpWindowKeys.Add(("{0}|{1}" -f $portInfo.process_id, [string]$page.title))
    $record = [ordered]@{
      source = "cdp"
      port = $portInfo.port
      process_name = $portInfo.process_name
      process_id = $portInfo.process_id
      is_ziniao = $portInfo.is_ziniao
      reachable = $true
      page_url = [string]$page.url
      page_title = [string]$page.title
      platform = $match.platform
      page_kind = $match.page_kind
      match_confidence = $match.confidence
      login_signal = if ($match.platform -ne "unknown") { "known_app_page_open" } else { "unknown_page_open" }
    }
    if ($IncludeWebSocketUrl) {
      $record.webSocketDebuggerUrl = [string]$page.webSocketDebuggerUrl
    }
    $windows += [pscustomobject]$record
  }
}

foreach ($item in $visibleBrowserWindows) {
  $key = "{0}|{1}" -f $item.process_id, $item.page_title
  if ($cdpWindowKeys.Contains($key)) {
    continue
  }
  $match = Get-KnownPageMatch -Url "" -Title ([string]$item.page_title)
  $windows += [pscustomobject]([ordered]@{
    source = "window_title"
    port = $null
    process_name = $item.process_name
    process_id = $item.process_id
    is_ziniao = $item.is_ziniao
    reachable = $null
    page_url = $null
    page_title = $item.page_title
    platform = $match.platform
    page_kind = $match.page_kind
    match_confidence = $match.confidence
    login_signal = if ($match.platform -ne "unknown") { "known_title_open" } else { "visible_browser_window_open" }
  })
}

$knownWindows = @($windows | Where-Object { $_.platform -and $_.platform -ne "unknown" })
$sellerWindows = @($knownWindows | Where-Object { $_.page_kind -eq "seller_center" })
$xinjianWindows = @($knownWindows | Where-Object { $_.platform -eq "xinjian_erp" })
$shopsSummary = @($sellerWindows | ForEach-Object {
  [ordered]@{
    name = $_.page_title
    platform = $_.platform
    url = $_.page_url
    port = $_.port
    source = "cdp_window_detect"
    login_signal = $_.login_signal
  }
})

$payload = [ordered]@{
  ok = $true
  scanned_at = $scanStarted.ToString("o")
  ziniao_only = [bool]$ZiniaoOnly
  scanned_ports = @($debugPorts | Select-Object port, process_name, process_id, is_ziniao)
  visible_browser_windows = @($visibleBrowserWindows)
  windows = @($windows)
  visible_windows_count = $visibleBrowserWindows.Count
  known_windows_count = $knownWindows.Count
  seller_windows_count = $sellerWindows.Count
  xinjian_windows_count = $xinjianWindows.Count
  detected_shops_count = $shopsSummary.Count
  detected_shops = $shopsSummary
  note = "Known pages are detected from DevTools URL/title when available, otherwise from normal window title only. No cookie/token/session was read. This is a weak open-window signal, not a verified authenticated API call."
}

if ($Json) {
  $payload | ConvertTo-Json -Depth 12
} else {
  if ($debugPorts.Count -eq 0) {
    Write-Host "No debuggable browser process found (ziniaobrowser.exe / chrome.exe / msedge.exe with --remote-debugging-port)."
  } else {
    Write-Host ("Scanned {0} debug port(s), found {1} known page(s), {2} seller-center window(s), {3} Xinjian window(s)." -f $debugPorts.Count, $knownWindows.Count, $sellerWindows.Count, $xinjianWindows.Count)
    foreach ($shop in $shopsSummary) {
      Write-Host ("- [{0}] {1} -> {2}" -f $shop.platform, $shop.name, $shop.url)
    }
  }
}
