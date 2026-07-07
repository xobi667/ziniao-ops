[CmdletBinding(PositionalBinding = $false)]
param(
  [string[]]$StoreName = @(),
  [int]$Days = 7,
  [string]$StartDate = "",
  [string]$EndDate = "",
  [int[]]$Port = @(),
  [string]$Url = "https://erp.xinjianerp.com/index/home",
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

function Get-ZiniaoDebugPorts {
  $ports = @()
  Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -eq "ziniaobrowser.exe" } |
    ForEach-Object {
      $cmd = [string]$_.CommandLine
      foreach ($match in [regex]::Matches($cmd, "--remote-debugging-port=(\d+)")) {
        $ports += [int]$match.Groups[1].Value
      }
    }
  return @($ports | Sort-Object -Unique)
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

function Test-LoadedXinjianPage([int]$CdpPort) {
  $pages = Get-CdpPages -CdpPort $CdpPort
  return [bool]($pages |
    Where-Object {
      $_.type -eq "page" -and
      [string]$_.url -match "erp\.xinjianerp\.com" -and
      [string]$_.title -match "心舰"
    } |
    Select-Object -First 1)
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

if (!$Port -or $Port.Count -eq 0) {
  $Port = @(Get-ZiniaoDebugPorts)
}

$attempts = @()
foreach ($candidatePort in $Port) {
  if (!(Test-CdpPort -CdpPort $candidatePort)) {
    $attempts += [pscustomobject]@{
      port = $candidatePort
      ok = $false
      error = "cdp_port_not_reachable"
    }
    continue
  }
  $hadLoadedPage = Test-LoadedXinjianPage -CdpPort $candidatePort
  $opened = if ($hadLoadedPage) { $false } else { Open-CdpUrl -CdpPort $candidatePort -TargetUrl $Url }
  if ($opened) {
    Start-Sleep -Seconds 5
  } else {
    Start-Sleep -Seconds 1
  }
  $argsList = @(
    "-ExecutionPolicy", "Bypass",
    "-File", (Join-Path $PSScriptRoot "fetch-xinjian-browser-data.ps1"),
    "-Port", ([string]$candidatePort),
    "-StoreName", ($StoreName -join ","),
    "-Days", ([string]$Days),
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
  $attempt = [pscustomobject]@{
    port = $candidatePort
    opened_url = $opened
    ok = [bool]$result.ok
    result = $result
  }
  $attempts += $attempt
  if ($attempt.ok) {
    $payload = [ordered]@{
      ok = $true
      method = "ziniao_cdp"
      port = $candidatePort
      login_state = $result.login_state
      result = $result
      output = $result.output
      excel_output = $result.excel_output
      stores_matched = @($result.stores_matched)
      stores_not_found = @($result.stores_not_found)
    }
    if ($Json) { $payload | ConvertTo-Json -Depth 14 } else { Write-Host "XINJIAN_ZINIAO_OK"; Write-Host "Excel: $($result.excel_output)" }
    exit 0
  }
}

$lastResult = $attempts |
  Where-Object { $_.result } |
  Select-Object -Last 1 -ExpandProperty result
$nextAction = if (!$Port -or $Port.Count -eq 0) {
  "open_ziniao_store_browser_first"
} elseif ($lastResult -and $lastResult.next_action) {
  $lastResult.next_action
} elseif ($lastResult -and $lastResult.login_required) {
  "manual_xinjian_login_in_ziniao_required"
} else {
  "check_response_or_export_hourly_data"
}

$payload = [ordered]@{
  ok = $false
  method = "ziniao_cdp"
  ports = @($Port)
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
  Write-Host "XINJIAN_ZINIAO_BLOCKED"
  if (!$Port -or $Port.Count -eq 0) {
    Write-Host "No running Ziniao browser debug port was found."
  } elseif ($nextAction -eq "manual_login_required" -or $nextAction -eq "manual_xinjian_login_in_ziniao_required") {
    Write-Host "Ziniao browser was reachable, but Xinjian still requires login."
  } elseif ($nextAction -eq "target_stores_not_found_in_xinjian") {
    Write-Host "Xinjian is logged in, but the requested stores were not found in the current account."
  } else {
    Write-Host "Ziniao browser was reachable, but no report was generated."
  }
}
