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

function Test-NonBusinessXinjianPath {
  param([string]$Path)
  $value = Normalize-UrlPath -Path $Path
  return $value -match "^/(login|xtlogin|sso|social-login|401|404|redirect)(/|$)" -or
    $value -match "^/index/(noaccess|ad-no-auth)(/|$)"
}

function Get-XinjianPageKind {
  param([string]$PageUrl)
  if (!$PageUrl) { return "unknown" }
  try {
    $uri = [uri]$PageUrl
  } catch {
    return "unknown"
  }
  if ($uri.Host -ne "erp.xinjianerp.com") { return "unknown" }
  $path = Normalize-UrlPath -Path $uri.AbsolutePath
  if ($path -match "^/(login|xtlogin|sso|social-login|redirect)(/|$)") { return "login_page" }
  if ($path -match "^/(401|404)(/|$)" -or $path -match "^/index/(noaccess|ad-no-auth)(/|$)") { return "non_business_page" }
  return "business_page"
}

function Get-NextActionForPageKind {
  param(
    [bool]$PortReady,
    [string]$PageKind
  )
  if (!$PortReady) { return "browser_started_but_devtools_not_ready" }
  if ($PageKind -eq "business_page") { return "xinjian_business_page_ready" }
  if ($PageKind -eq "non_business_page") { return "open_valid_xinjian_business_page" }
  return "manual_login_required_in_debuggable_xinjian_browser"
}

function Get-TargetPageScore {
  param(
    [object]$Page,
    [string]$TargetUrl
  )
  if (!$Page -or !$Page.url) { return -1 }
  try {
    $pageUri = [uri]([string]$Page.url)
    $targetUri = [uri]$TargetUrl
  } catch {
    return -1
  }
  if ($pageUri.Host -ne $targetUri.Host) { return -1 }

  $score = 10
  $pagePath = Normalize-UrlPath -Path $pageUri.AbsolutePath
  $targetPath = Normalize-UrlPath -Path $targetUri.AbsolutePath
  if (!(Test-NonBusinessXinjianPath -Path $pagePath)) { $score += 100 }
  if ($pagePath -eq $targetPath) { $score += 80 }
  if ($pagePath -eq "/login") {
    $decodedQuery = [uri]::UnescapeDataString($pageUri.Query)
    if ($decodedQuery -like "*redirect=$targetPath*") { $score += 20 }
  }
  return $score
}

function Select-BestTargetPage {
  param(
    [object[]]$Pages,
    [string]$TargetUrl
  )
  $scored = @($Pages | ForEach-Object {
      $score = Get-TargetPageScore -Page $_ -TargetUrl $TargetUrl
      if ($score -ge 0) {
        [pscustomobject]@{
          score = [int]$score
          page = $_
        }
      }
    } | Sort-Object -Property @{ Expression = "score"; Descending = $true })
  if ($scored.Count -eq 0) { return $null }
  return $scored[0]
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
$reusedPageScore = $null
$openedNewTab = $false
if ($alreadyRunning) {
  $bestPage = Select-BestTargetPage -Pages (Get-DevToolsPages -Port $Port) -TargetUrl $Url
  if ($bestPage) {
    $reusedPage = $bestPage.page
    $reusedPageScore = [int]$bestPage.score
  }
  if (!$reusedPage) {
    try {
      $encoded = [uri]::EscapeDataString($Url)
      $reusedPage = Invoke-RestMethod -Method Put -Uri "http://127.0.0.1:$Port/json/new?$encoded" -TimeoutSec 3
      $openedNewTab = $true
      $reusedPageScore = Get-TargetPageScore -Page $reusedPage -TargetUrl $Url
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
  $bestPage = Select-BestTargetPage -Pages (Get-DevToolsPages -Port $Port) -TargetUrl $Url
  if ($bestPage) {
    $reusedPage = $bestPage.page
    $reusedPageScore = [int]$bestPage.score
  }
}

$portReady = Test-DevToolsPort -Port $Port
$matchedPageKind = if ($reusedPage) { Get-XinjianPageKind -PageUrl ([string]$reusedPage.url) } else { "unknown" }
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
  matched_page_score = if ($null -ne $reusedPageScore) { [int]$reusedPageScore } else { $null }
  matched_page_kind = $matchedPageKind
  next_action = Get-NextActionForPageKind -PortReady $portReady -PageKind $matchedPageKind
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
