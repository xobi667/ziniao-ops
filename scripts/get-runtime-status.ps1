[CmdletBinding(PositionalBinding = $false)]
param(
  [int]$CacheTtlSeconds = 30,
  [switch]$Refresh,
  [switch]$Full,
  [switch]$ZiniaoOnly,
  [switch]$Json
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$localStateRoot = Join-Path $root ".ziniao-ops"
$cachePath = Join-Path $localStateRoot "runtime-status.cache.json"

function ConvertFrom-JsonLines($Lines) {
  $text = (($Lines | Out-String).Trim())
  if (!$text) { return $null }
  try {
    return $text | ConvertFrom-Json
  } catch {
    return $null
  }
}

function Write-Status($Payload, [int]$Code = 0) {
  if ($Json) {
    $Payload | ConvertTo-Json -Depth 14
  } else {
    Write-Host ("runtime_state: {0}" -f $Payload.runtime_state)
    Write-Host ("known_pages: {0}, seller_windows: {1}, xinjian_windows: {2}, visible_windows: {3}" -f $Payload.summary.known_windows, $Payload.summary.seller_windows, $Payload.summary.xinjian_windows, $Payload.summary.visible_windows)
    if ($Payload.next_actions) {
      foreach ($action in @($Payload.next_actions)) {
        Write-Host ("next: {0}" -f $action)
      }
    }
  }
  exit $Code
}

if (!$Refresh -and $CacheTtlSeconds -gt 0 -and (Test-Path -LiteralPath $cachePath)) {
  try {
    $cacheItem = Get-Item -LiteralPath $cachePath
    $ageSeconds = ((Get-Date) - $cacheItem.LastWriteTime).TotalSeconds
    if ($ageSeconds -lt $CacheTtlSeconds) {
      $cached = Get-Content -LiteralPath $cachePath -Raw | ConvertFrom-Json
      $cached | Add-Member -NotePropertyName from_cache -NotePropertyValue $true -Force
      $cached | Add-Member -NotePropertyName cache_age_seconds -NotePropertyValue ([int]$ageSeconds) -Force
      Write-Status $cached 0
    }
  } catch {
  }
}

$detectArgs = @(
  "-NoProfile",
  "-ExecutionPolicy", "Bypass",
  "-File", (Join-Path $PSScriptRoot "detect-ziniao-windows.ps1"),
  "-Json"
)
if ($ZiniaoOnly) {
  $detectArgs += "-ZiniaoOnly"
}

$windowRaw = @(& powershell @detectArgs 2>&1)
$windowStatus = ConvertFrom-JsonLines $windowRaw
if (!$windowStatus) {
  $windowStatus = [pscustomobject]@{
    ok = $false
    error = "window_detection_parse_failed"
    raw_output = ($windowRaw | Out-String)
    scanned_ports = @()
    windows = @()
    known_windows_count = 0
    seller_windows_count = 0
    xinjian_windows_count = 0
  }
}

$diagnose = $null
if ($Full) {
  $diagRaw = @(& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "diagnose-local.ps1") -Json 2>&1)
  $diagnose = ConvertFrom-JsonLines $diagRaw
  if (!$diagnose) {
    $diagnose = [pscustomobject]@{
      ok = $false
      error = "diagnose_parse_failed"
      raw_output = ($diagRaw | Out-String)
    }
  }
}

$windows = @($windowStatus.windows)
$knownWindows = @($windows | Where-Object { $_.platform -and $_.platform -ne "unknown" })
$sellerWindows = @($knownWindows | Where-Object { $_.page_kind -eq "seller_center" })
$xinjianWindows = @($knownWindows | Where-Object { $_.platform -eq "xinjian_erp" })

$runtimeState = "no_debug_browser"
if ($diagnose -and $diagnose.ziniao_sync_error) {
  $runtimeState = [string]$diagnose.ziniao_sync_error
} elseif ($diagnose -and $diagnose.can_sync_ziniao_shops) {
  $runtimeState = "ziniao_webdriver_ready"
} elseif ($xinjianWindows.Count -gt 0) {
  $runtimeState = "xinjian_window_detected"
} elseif ($sellerWindows.Count -gt 0) {
  $runtimeState = "seller_window_detected"
} elseif (@($windowStatus.scanned_ports).Count -gt 0) {
  $runtimeState = "debug_browser_detected"
}

$nextActions = @()
if ($runtimeState -eq "ziniao_webdriver_auth_fields_missing") {
  $nextActions += "Configure local-only ziniao.auth.local.json or ZINIAO_WEBDRIVER_* environment variables, then rerun setup-ziniao.ps1 -ResetStaleWebDriver."
} elseif ($runtimeState -eq "xinjian_window_detected") {
  $nextActions += "For verified Xinjian login/data state, run xinjian-ziniao-bridge.ps1 or fetch-xinjian-browser-data.ps1; window detection alone is only a weak signal."
} elseif ($runtimeState -eq "seller_window_detected") {
  $nextActions += "A known seller-center window is open. Treat it as window presence only; use CLI/WebDriver/API or page inspection for stronger task-specific verification."
} elseif ($runtimeState -eq "no_debug_browser") {
  $nextActions += "No debuggable Ziniao/Chrome/Edge window was found. Open the target store browser through Ziniao or use the WebDriver setup path."
}

$payload = [ordered]@{
  ok = $true
  checked_at = (Get-Date).ToString("o")
  from_cache = $false
  cache_ttl_seconds = $CacheTtlSeconds
  full = [bool]$Full
  runtime_state = $runtimeState
  summary = [ordered]@{
    scanned_ports = @($windowStatus.scanned_ports).Count
    visible_windows = @($windowStatus.visible_browser_windows).Count
    windows = @($windowStatus.windows).Count
    known_windows = $knownWindows.Count
    seller_windows = $sellerWindows.Count
    xinjian_windows = $xinjianWindows.Count
  }
  signals = [ordered]@{
    cdp_window_url = "weak_open_window_signal_no_secrets"
    ziniao_browser_list = "stronger_local_account_signal_when_full_probe_runs"
    xinjian_endpoint = "strong_authenticated_signal_only_when_xinjian_fetch_probe_runs"
  }
  window_detection = $windowStatus
  diagnose = if ($Full) {
    [ordered]@{
      ok = $diagnose.ok
      ready_for_shopee_tiktok = $diagnose.ready_for_shopee_tiktok
      ready_for_lazada = $diagnose.ready_for_lazada
      can_sync_ziniao_shops = $diagnose.can_sync_ziniao_shops
      detected_ziniao_shops_count = $diagnose.detected_ziniao_shops_count
      ziniao_sync_error = $diagnose.ziniao_sync_error
      webdriver_auth_complete = $diagnose.webdriver_auth_complete
      webdriver_auth_fields_present = $diagnose.webdriver_auth_fields_present
      issues = @($diagnose.issues)
    }
  } else {
    $null
  }
  next_actions = $nextActions
}

try {
  New-Item -ItemType Directory -Force -Path $localStateRoot | Out-Null
  $payload | ConvertTo-Json -Depth 14 | Set-Content -LiteralPath $cachePath -Encoding UTF8
} catch {
}

Write-Status $payload 0
