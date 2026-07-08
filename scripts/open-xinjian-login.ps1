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

function Get-DevToolsPages {
  param([int]$Port)
  try {
    $pages = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/json/list" -TimeoutSec 2
    return @($pages | Where-Object { $_.type -eq "page" -and $_.url })
  } catch {
    return @()
  }
}

function Normalize-UrlPath {
  param([string]$Path)
  $value = [string]$Path
  if (!$value.StartsWith("/")) { $value = "/$value" }
  $value = $value -replace "/+", "/"
  if ($value.Length -gt 1) { $value = $value.TrimEnd("/") }
  return $value
}

function Test-TargetPageMatch {
  param(
    [object]$Page,
    [string]$TargetUrl
  )
  if (!$Page -or !$Page.url) { return $false }
  try {
    $pageUri = [uri]([string]$Page.url)
    $targetUri = [uri]$TargetUrl
  } catch {
    return $false
  }
  if ($pageUri.Host -ne $targetUri.Host) { return $false }

  $pagePath = Normalize-UrlPath -Path $pageUri.AbsolutePath
  $targetPath = Normalize-UrlPath -Path $targetUri.AbsolutePath
  if ($pagePath -eq $targetPath) { return $true }
  if ($pagePath -eq "/login") {
    $decodedQuery = [uri]::UnescapeDataString($pageUri.Query)
    if ($decodedQuery -like "*redirect=$targetPath*") { return $true }
  }

  # Any page on the same Xinjian host is a usable manual-login handoff target.
  return $true
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
$reusedPage = $null
$openedNewTab = $false
if ($alreadyRunning) {
  $reusedPage = Get-DevToolsPages -Port $Port | Where-Object { Test-TargetPageMatch -Page $_ -TargetUrl $Url } | Select-Object -First 1
  if (!$reusedPage) {
    try {
      $encoded = [uri]::EscapeDataString($Url)
      $reusedPage = Invoke-RestMethod -Method Put -Uri "http://127.0.0.1:$Port/json/new?$encoded" -TimeoutSec 3
      $openedNewTab = $true
    } catch {
      # The existing debug browser is still usable; the user can navigate manually if new-tab fails.
    }
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
  $openedNewTab = $true
  $reusedPage = Get-DevToolsPages -Port $Port | Where-Object { Test-TargetPageMatch -Page $_ -TargetUrl $Url } | Select-Object -First 1
}

$portReady = Test-DevToolsPort -Port $Port
$result = [ordered]@{
  ok = $portReady
  browser = $browser
  port = $Port
  url = $Url
  user_data_dir = $UserDataDir
  window = if ($NormalWindow) { "normal" } else { "minimized" }
  reused_existing_page = [bool]($alreadyRunning -and $reusedPage -and !$openedNewTab)
  opened_new_tab = [bool]$openedNewTab
  matched_page_url = if ($reusedPage) { [string]$reusedPage.url } else { "" }
  matched_page_title = if ($reusedPage) { [string]$reusedPage.title } else { "" }
  matched_page_id = if ($reusedPage) { [string]$reusedPage.id } else { "" }
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
