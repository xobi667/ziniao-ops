[CmdletBinding(PositionalBinding = $false)]
param(
  [string[]]$StoreName = @(),
  [int]$Days = 7,
  [string]$StartDate = "",
  [string]$EndDate = "",
  [int[]]$Port = @(),
  [string]$Url = "https://erp.xinjianerp.com/index/home",
  [switch]$ZiniaoOnly,
  [switch]$NoAutoOpen,
  [switch]$Json
)

$ErrorActionPreference = "Stop"

$StoreName = @(
  foreach ($name in $StoreName) {
    if ($name) {
      $name -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    }
  }
)

function ConvertFrom-JsonLines($Lines) {
  $text = (($Lines | Out-String).Trim())
  if (!$text) { return $null }
  try {
    return $text | ConvertFrom-Json
  } catch {
    return $null
  }
}

function Get-RuntimeStatus {
  $raw = @(& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "get-runtime-status.ps1") -Refresh -Json 2>&1)
  $status = ConvertFrom-JsonLines $raw
  if ($status) { return $status }
  return [pscustomobject]@{
    ok = $false
    error = "runtime_status_parse_failed"
    raw_output = ($raw | Out-String)
  }
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

function Get-PageScore {
  param(
    [object]$Page,
    [string]$TargetUrl
  )

  $url = [string]$Page.url
  $title = [string]$Page.title
  $score = 0
  if ($Page.type -eq "page") { $score += 10 }
  if ($url -match "erp\.xinjianerp\.com") { $score += 50 }
  if ($title -match "心舰") { $score += 40 }
  if ($title -match "首页|home") { $score += 15 }
  if ($url -match "^chrome-extension://") { $score -= 1000 }

  if ($TargetUrl) {
    try {
      $target = [Uri]$TargetUrl
      $current = [Uri]$url
      if ($current.Host -eq $target.Host) { $score += 100 }
      if ($current.AbsoluteUri -eq $target.AbsoluteUri) { $score += 160 }
      $targetPath = $target.AbsolutePath.TrimEnd("/")
      $currentPath = $current.AbsolutePath.TrimEnd("/")
      if ($targetPath -and $currentPath) {
        if ($targetPath -eq $currentPath) {
          $score += 60
        } elseif ($currentPath.StartsWith($targetPath) -or $targetPath.StartsWith($currentPath)) {
          $score += 30
        }
      }
    } catch {
      if ($url -like "*$TargetUrl*") { $score += 40 }
    }
  }

  return $score
}

function Get-TargetPages {
  param(
    [object]$PortInfo,
    [string]$TargetUrl
  )

  $pages = Get-CdpPages -CdpPort $PortInfo.port
  return @($pages |
    Where-Object { $_.webSocketDebuggerUrl -and $_.type -eq "page" } |
    ForEach-Object {
      $score = Get-PageScore -Page $_ -TargetUrl $TargetUrl
      if ($score -gt 0) {
        [pscustomobject]@{
          port = $PortInfo.port
          process_id = $PortInfo.process_id
          process_name = $PortInfo.process_name
          is_ziniao = $PortInfo.is_ziniao
          score = $score
          page_url = [string]$_.url
          page_title = [string]$_.title
          webSocketDebuggerUrl = [string]$_.webSocketDebuggerUrl
        }
      }
    } |
    Sort-Object @{ Expression = "score"; Descending = $true }, @{ Expression = "is_ziniao"; Descending = $true })
}

function Open-CdpUrl([int]$CdpPort, [string]$TargetUrl) {
  $encoded = [uri]::EscapeDataString($TargetUrl)
  foreach ($endpoint in @(
      "http://127.0.0.1:$CdpPort/json/new?$encoded",
      "http://127.0.0.1:$CdpPort/json/new?url=$encoded"
    )) {
    foreach ($method in @("PUT", "GET")) {
      try {
        Invoke-RestMethod -Method $method -Uri $endpoint -TimeoutSec 5 | Out-Null
        return $true
      } catch {
      }
    }
  }
  return $false
}

function Invoke-AutoOpenXinjian {
  param([int]$CdpPort)

  $openScript = Join-Path $PSScriptRoot "open-xinjian-login.ps1"
  if (!(Test-Path -LiteralPath $openScript)) {
    return [pscustomobject]@{
      ok = $false
      error = "open_xinjian_login_script_missing"
      path = $openScript
    }
  }
  $raw = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $openScript -Port $CdpPort -Url $Url -Json 2>&1)
  $json = ConvertFrom-JsonLines $raw
  return [pscustomobject]@{
    ok = ($LASTEXITCODE -eq 0 -and $json -and [bool]$json.ok)
    exit_code = $LASTEXITCODE
    port = $CdpPort
    result = $json
    raw_output = if ($json) { $null } else { $raw }
  }
}

function Invoke-XinjianFetch {
  param(
    [object]$Candidate,
    [bool]$OpenedUrl
  )

  $argsList = @(
    "-ExecutionPolicy", "Bypass",
    "-File", (Join-Path $PSScriptRoot "fetch-xinjian-browser-data.ps1"),
    "-Port", ([string]$Candidate.port),
    "-StoreName", ($StoreName -join ","),
    "-Days", ([string]$Days),
    "-PageUrl", $Url,
    "-WebSocketUrl", $Candidate.webSocketDebuggerUrl,
    "-Json"
  )
  if ($StartDate) { $argsList += @("-StartDate", $StartDate) }
  if ($EndDate) { $argsList += @("-EndDate", $EndDate) }

  $raw = @(& powershell @argsList 2>&1)
  try {
    $result = ($raw | Out-String | ConvertFrom-Json)
  } catch {
    $result = [pscustomobject]@{
      ok = $false
      parse_failed = $true
      raw = ($raw | Out-String)
    }
  }

  return [pscustomobject]@{
    port = $Candidate.port
    process_name = $Candidate.process_name
    process_id = $Candidate.process_id
    is_ziniao = $Candidate.is_ziniao
    page_url = $Candidate.page_url
    page_title = $Candidate.page_title
    page_score = $Candidate.score
    opened_url = $OpenedUrl
    ok = [bool]$result.ok
    login_state = if ($result.PSObject.Properties.Match("login_state").Count -gt 0) { $result.login_state } else { $null }
    next_action = if ($result.PSObject.Properties.Match("next_action").Count -gt 0) { $result.next_action } else { $null }
    result = $result
  }
}

function Write-SuccessAndExit {
  param([object]$Attempt)

  $payload = [ordered]@{
    ok = $true
    method = "browser_cdp_auto_detect"
    port = $Attempt.port
    process_name = $Attempt.process_name
    matched_existing_page = -not [bool]$Attempt.opened_url
    page_url = $Attempt.result.page_url
    page_title = $Attempt.result.page_title
    login_state = $Attempt.result.login_state
    result = $Attempt.result
    output = $Attempt.result.output
    excel_output = $Attempt.result.excel_output
    stores_matched = @($Attempt.result.stores_matched)
    stores_not_found = @($Attempt.result.stores_not_found)
  }
  if ($Json) {
    $payload | ConvertTo-Json -Depth 14
  } else {
    Write-Host "XINJIAN_BROWSER_AUTO_DETECT_OK"
    Write-Host "Port: $($Attempt.port)"
    Write-Host "Process: $($Attempt.process_name)"
    Write-Host "Excel: $($Attempt.result.excel_output)"
  }
  exit 0
}

$runtimeStatus = Get-RuntimeStatus
$runtimeXinjianWindows = @()
if ($runtimeStatus -and $runtimeStatus.window_detection) {
  $runtimeXinjianWindows = @($runtimeStatus.window_detection.windows | Where-Object {
      $_.platform -eq "xinjian_erp"
    })
}
$nonDebugXinjianWindows = @($runtimeXinjianWindows | Where-Object { !$_.port })

$debugPorts = @(Get-DebugBrowserPorts -ExplicitPort $Port -ZiniaoOnly:$ZiniaoOnly)
$reachablePorts = @()
$attempts = @()

foreach ($portInfo in $debugPorts) {
  if (Test-CdpPort -CdpPort $portInfo.port) {
    $reachablePorts += $portInfo
  } else {
    $attempts += [pscustomobject]@{
      port = $portInfo.port
      process_name = $portInfo.process_name
      process_id = $portInfo.process_id
      is_ziniao = $portInfo.is_ziniao
      opened_url = $false
      ok = $false
      error = "cdp_port_not_reachable"
    }
  }
}

$detectedPages = @()
foreach ($portInfo in $reachablePorts) {
  $detectedPages += @(Get-TargetPages -PortInfo $portInfo -TargetUrl $Url)
}
$detectedPages = @($detectedPages |
  Sort-Object @{ Expression = "score"; Descending = $true }, @{ Expression = "is_ziniao"; Descending = $true })

$autoOpen = $null
if (!$NoAutoOpen -and (!$detectedPages -or $detectedPages.Count -eq 0) -and $runtimeXinjianWindows.Count -eq 0) {
  $autoPort = if ($Port -and $Port.Count -gt 0) { [int]$Port[0] } else { 9339 }
  $autoOpen = Invoke-AutoOpenXinjian -CdpPort $autoPort
  if ($autoOpen.ok) {
    Start-Sleep -Seconds 2
    $debugPorts = @(Get-DebugBrowserPorts -ExplicitPort @($autoPort) -ZiniaoOnly:$false)
    $reachablePorts = @()
    foreach ($portInfo in $debugPorts) {
      if (Test-CdpPort -CdpPort $portInfo.port) {
        $reachablePorts += $portInfo
      } else {
        $attempts += [pscustomobject]@{
          port = $portInfo.port
          process_name = $portInfo.process_name
          process_id = $portInfo.process_id
          is_ziniao = $portInfo.is_ziniao
          opened_url = $false
          ok = $false
          error = "auto_opened_cdp_port_not_reachable"
        }
      }
    }
    $detectedPages = @()
    foreach ($portInfo in $reachablePorts) {
      $detectedPages += @(Get-TargetPages -PortInfo $portInfo -TargetUrl $Url)
    }
    $detectedPages = @($detectedPages |
      Sort-Object @{ Expression = "score"; Descending = $true }, @{ Expression = "is_ziniao"; Descending = $true })
  }
}

$attemptedSockets = [System.Collections.Generic.HashSet[string]]::new()
foreach ($candidate in $detectedPages) {
  if (!$attemptedSockets.Add($candidate.webSocketDebuggerUrl)) {
    continue
  }
  $attempt = Invoke-XinjianFetch -Candidate $candidate -OpenedUrl:$false
  $attempts += $attempt
  if ($attempt.ok) {
    Write-SuccessAndExit -Attempt $attempt
  }
}

$fallbackOpenPorts = if ($Port -and $Port.Count -gt 0) {
  $reachablePorts
} else {
  @($reachablePorts | Where-Object { $_.is_ziniao })
}

foreach ($portInfo in $fallbackOpenPorts) {
  $opened = Open-CdpUrl -CdpPort $portInfo.port -TargetUrl $Url
  if (!$opened) {
    $attempts += [pscustomobject]@{
      port = $portInfo.port
      process_name = $portInfo.process_name
      process_id = $portInfo.process_id
      is_ziniao = $portInfo.is_ziniao
      opened_url = $false
      ok = $false
      error = "open_target_url_failed"
    }
    continue
  }

  Start-Sleep -Seconds 5
  $openedPage = @(Get-TargetPages -PortInfo $portInfo -TargetUrl $Url | Select-Object -First 1)
  if (!$openedPage -or !$openedPage[0].webSocketDebuggerUrl) {
    $attempts += [pscustomobject]@{
      port = $portInfo.port
      process_name = $portInfo.process_name
      process_id = $portInfo.process_id
      is_ziniao = $portInfo.is_ziniao
      opened_url = $true
      ok = $false
      error = "opened_page_not_detected"
    }
    continue
  }

  $candidate = $openedPage[0]
  if (!$attemptedSockets.Add($candidate.webSocketDebuggerUrl)) {
    continue
  }
  $attempt = Invoke-XinjianFetch -Candidate $candidate -OpenedUrl:$true
  $attempts += $attempt
  if ($attempt.ok) {
    Write-SuccessAndExit -Attempt $attempt
  }
}

$lastResult = $attempts |
  Where-Object { $_.PSObject.Properties.Match("result").Count -gt 0 -and $_.result } |
  Select-Object -Last 1 -ExpandProperty result

$nextAction = if ((!$debugPorts -or $debugPorts.Count -eq 0) -and $nonDebugXinjianWindows.Count -gt 0) {
  "xinjian_window_detected_without_debug_port"
} elseif (!$debugPorts -or $debugPorts.Count -eq 0) {
  "open_ziniao_store_browser_first"
} elseif ((!$detectedPages -or $detectedPages.Count -eq 0) -and $nonDebugXinjianWindows.Count -gt 0) {
  "xinjian_window_detected_without_debug_port"
} elseif (!$detectedPages -or $detectedPages.Count -eq 0) {
  "target_browser_window_not_detected"
} elseif ($lastResult -and $lastResult.next_action) {
  $lastResult.next_action
} elseif ($lastResult -and $lastResult.login_required) {
  "manual_xinjian_login_in_ziniao_required"
} else {
  "check_response_or_export_hourly_data"
}

$payload = [ordered]@{
  ok = $false
  method = "browser_cdp_auto_detect"
  requested_url = $Url
  scanned_ports = @($debugPorts | Select-Object port, process_name, process_id, is_ziniao)
  reachable_ports = @($reachablePorts | Select-Object port, process_name, process_id, is_ziniao)
  detected_pages = @($detectedPages | Select-Object port, process_name, process_id, is_ziniao, score, page_url, page_title)
  runtime_status = [ordered]@{
    runtime_state = $runtimeStatus.runtime_state
    summary = $runtimeStatus.summary
    xinjian_windows = @($runtimeXinjianWindows | Select-Object source, process_name, process_id, port, page_title, page_url, match_confidence, login_signal)
  }
  auto_open = $autoOpen
  attempts = @($attempts)
  login_state = if ($lastResult) { $lastResult.login_state } else { $null }
  stores_matched = if ($lastResult) { @($lastResult.stores_matched) } else { @() }
  stores_not_found = if ($lastResult) { @($lastResult.stores_not_found) } else { @() }
  store_suggestions = if ($lastResult) { $lastResult.store_suggestions } else { $null }
  next_action = $nextAction
}

if ($Json) {
  $payload | ConvertTo-Json -Depth 14
} else {
  Write-Host "XINJIAN_BROWSER_AUTO_DETECT_BLOCKED"
  if ($autoOpen -and $autoOpen.ok -and ($nextAction -eq "manual_login_required" -or $nextAction -eq "manual_xinjian_login_in_ziniao_required")) {
    Write-Host "Opened a controllable Xinjian browser window. Complete login there, then run the same command again."
  } elseif ($nextAction -eq "xinjian_window_detected_without_debug_port") {
    Write-Host "A Xinjian window was detected by title, but it has no reachable DevTools port. Reopen it through the Ziniao/CDP bridge or a browser started with remote debugging."
  } elseif (!$debugPorts -or $debugPorts.Count -eq 0) {
    Write-Host "No running browser debug port was found. Open a Ziniao browser window first."
  } elseif (!$detectedPages -or $detectedPages.Count -eq 0) {
    Write-Host "No debuggable browser page matched the target Xinjian URL."
  } elseif ($nextAction -eq "manual_login_required" -or $nextAction -eq "manual_xinjian_login_in_ziniao_required") {
    Write-Host "A target browser page was found, but Xinjian still requires login there."
  } elseif ($nextAction -eq "target_stores_not_found_in_xinjian") {
    Write-Host "Xinjian is logged in, but the requested stores were not found in the current account."
  } else {
    Write-Host "A target browser page was found, but no report was generated."
  }
}
