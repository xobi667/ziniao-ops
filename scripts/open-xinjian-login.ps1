[CmdletBinding(PositionalBinding = $false)]
param(
  [int]$Port = 9339,
  [string]$Url = "https://erp.xinjianerp.com/index/home",
  [string]$UserDataDir = "",
  [switch]$NormalWindow,
  [switch]$Json
)

$ErrorActionPreference = "Stop"

function Find-Browser {
  $candidates = @(
    (Get-Command chrome.exe -ErrorAction SilentlyContinue).Source,
    "C:\Program Files\Google\Chrome\Application\chrome.exe",
    "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
    (Get-Command msedge.exe -ErrorAction SilentlyContinue).Source,
    "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    "C:\Program Files\Microsoft\Edge\Application\msedge.exe"
  ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique
  return ($candidates | Select-Object -First 1)
}

function Test-DevToolsPort {
  param([int]$Port)
  try {
    Invoke-RestMethod -Uri "http://127.0.0.1:$Port/json/version" -TimeoutSec 2 | Out-Null
    return $true
  } catch {
    return $false
  }
}

if (!$UserDataDir) {
  $UserDataDir = Join-Path ([System.IO.Path]::GetTempPath()) "codex-xinjian-browser-profile-$Port"
}
New-Item -ItemType Directory -Force -Path $UserDataDir | Out-Null

$browser = Find-Browser
if (!$browser) {
  throw "No Edge or Chrome executable was found."
}

$alreadyRunning = Test-DevToolsPort -Port $Port
if ($alreadyRunning) {
  try {
    $encoded = [uri]::EscapeDataString($Url)
    Invoke-RestMethod -Method Put -Uri "http://127.0.0.1:$Port/json/new?$encoded" -TimeoutSec 3 | Out-Null
  } catch {
    # The existing debug browser is still usable; the user can navigate manually if new-tab fails.
  }
} else {
  $args = @(
    "--remote-debugging-address=127.0.0.1",
    "--remote-debugging-port=$Port",
    "--user-data-dir=$UserDataDir",
    "--no-first-run",
    "--no-default-browser-check",
    "--new-window",
    $Url
  )
  $windowStyle = if ($NormalWindow) { "Normal" } else { "Minimized" }
  Start-Process -FilePath $browser -ArgumentList $args -WindowStyle $windowStyle | Out-Null
  Start-Sleep -Seconds 2
}

$portReady = Test-DevToolsPort -Port $Port
$result = [ordered]@{
  ok = $portReady
  browser = $browser
  port = $Port
  url = $Url
  user_data_dir = $UserDataDir
  window = if ($NormalWindow) { "normal" } else { "minimized" }
  next_action = if ($portReady) { "manual_login_then_fetch" } else { "browser_started_but_devtools_not_ready" }
  fetch_command = "powershell -ExecutionPolicy Bypass -File scripts\fetch-xinjian-browser-data.ps1 -Port $Port -StoreName `"<店铺A>,<店铺B>`" -Days 7 -Json"
}

if ($Json) {
  $result | ConvertTo-Json -Depth 6
} else {
  if ($portReady) {
    Write-Host "XINJIAN_LOGIN_BROWSER_READY"
    Write-Host "Port: $Port"
    Write-Host "Window: $($result.window)"
    Write-Host "After manual login, run:"
    Write-Host $result.fetch_command
  } else {
    Write-Host "XINJIAN_LOGIN_BROWSER_NOT_READY"
  }
}

if (!$portReady) { exit 2 }
