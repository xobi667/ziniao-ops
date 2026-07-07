param(
  [int]$LoginTimeoutSeconds = 600,
  [switch]$AllowGuiMouse,
  [switch]$DryRun,
  [switch]$Json,
  [string]$Out = ""
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath $PSScriptRoot).Path
. (Join-Path $root "scripts\path-utils.ps1")

if (!$Out) {
  $Out = Join-Path $root "shops.json"
}

function Get-PythonCommand {
  $configPath = Join-Path $root "ziniao.local.json"
  if (Test-Path -LiteralPath $configPath) {
    try {
      $cfg = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
      if ($cfg.python_path) {
        $pythonPath = Resolve-ZiniaoOpsRepoPath $root ([string]$cfg.python_path)
        if (Test-Path -LiteralPath $pythonPath -PathType Leaf) { return @($pythonPath) }
      }
      if ($cfg.local_state_root) {
        $venvPython = Join-Path (Resolve-ZiniaoOpsRepoPath $root ([string]$cfg.local_state_root)) "tools\python-venv\Scripts\python.exe"
        if (Test-Path -LiteralPath $venvPython -PathType Leaf) { return @($venvPython) }
      }
    } catch {
    }
  }
  $defaultVenvPython = Join-Path $root ".ziniao-ops\tools\python-venv\Scripts\python.exe"
  if (Test-Path -LiteralPath $defaultVenvPython -PathType Leaf) { return @($defaultVenvPython) }
  if (Get-Command python -ErrorAction SilentlyContinue) { return @("python") }
  if (Get-Command py -ErrorAction SilentlyContinue) { return @("py", "-3") }
  return @()
}

function ConvertFrom-JsonLines($Lines) {
  $text = (($Lines | Out-String).Trim())
  if (!$text) { return $null }
  try {
    return $text | ConvertFrom-Json
  } catch {
    return $null
  }
}

function Get-WebDriverUserDataDir {
  $configPath = Join-Path $root "ziniao.local.json"
  if (Test-Path -LiteralPath $configPath) {
    try {
      $cfg = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
      foreach ($prop in @("webdriver_user_data_dir", "user_data_dir")) {
        if ($cfg.PSObject.Properties.Name -contains $prop -and $cfg.$prop) {
          return (Resolve-ZiniaoOpsRepoPath $root ([string]$cfg.$prop))
        }
      }
    } catch {
    }
  }
  if ($env:APPDATA) {
    return (Join-Path $env:APPDATA "ziniaobrowser\instances\userdata1")
  }
  return ""
}

function Test-WebDriverUserDataInUse {
  $dir = Get-WebDriverUserDataDir
  if (!$dir) { return $false }
  try {
    $resolved = if (Test-Path -LiteralPath $dir) { (Resolve-Path -LiteralPath $dir).Path } else { $dir }
    $escaped = [regex]::Escape($resolved)
    $procs = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
      Where-Object {
        $_.Name -eq "ziniao.exe" -and
        $_.CommandLine -match "--user-data-dir=.*$escaped" -and
        $_.CommandLine -notmatch "--run_type=web_driver"
      })
    return ($procs.Count -gt 0)
  } catch {
    return $false
  }
}

function Write-SetupResult($Payload, [int]$Code = 0) {
  if ($Json) {
    $Payload | ConvertTo-Json -Depth 12
  } else {
    if ($Payload.message) { Write-Host $Payload.message }
    if ($Payload.error) { Write-Host ("错误: {0}" -f $Payload.error) }
    if ($Payload.shops_count -ne $null) { Write-Host ("检测到店铺数: {0}" -f $Payload.shops_count) }
    if ($Payload.out) { Write-Host ("本机店铺缓存: {0}" -f $Payload.out) }
    if ($Payload.next_step) { Write-Host ("下一步: {0}" -f $Payload.next_step) }
  }
  exit $Code
}

[array]$python = @(Get-PythonCommand)
if ($python.Count -eq 0) {
  Write-SetupResult ([ordered]@{
    ok = $false
    method = "setup_ziniao"
    error = "python_missing"
    message = "Python 3 was not found on this computer. Install Python 3, or make sure python/py is available in PATH."
    next_step = "Install Python, then run .\setup-ziniao.ps1 again."
  }) 3
}

$pythonExe = $python[0]
$pythonArgs = @()
if ($python.Count -gt 1) { $pythonArgs = @($python[1..($python.Count - 1)]) }

$guiScript = Join-Path $root "scripts\ziniao-gui-open.py"
$syncScript = Join-Path $root "scripts\sync-ziniao-shops.py"
if (!(Test-Path -LiteralPath $guiScript)) {
  Write-SetupResult ([ordered]@{
    ok = $false
    method = "setup_ziniao"
    error = "ziniao_gui_script_missing"
    message = "Missing Ziniao window check script."
    path = $guiScript
  }) 1
}
if (!(Test-Path -LiteralPath $syncScript)) {
  Write-SetupResult ([ordered]@{
    ok = $false
    method = "setup_ziniao"
    error = "sync_script_missing"
    message = "Missing Ziniao shop sync script."
    path = $syncScript
  }) 1
}

$loginJson = $null
if ($AllowGuiMouse) {
  if (!$Json) {
    Write-Host "Opening or foregrounding Ziniao. If the Ziniao login page appears, complete login in the Ziniao window."
    Write-Host ("Waiting up to {0} seconds; after login, this script will scan local Ziniao shops." -f $LoginTimeoutSeconds)
  }

  $loginArgs = @(
    $guiScript,
    "--shop-name", "__login_check__",
    "--query", "__login_check__",
    "--view", "home",
    "--login-check-only",
    "--login-timeout", ([string]$LoginTimeoutSeconds),
    "--json"
  )
  $loginOutput = @(& $pythonExe @pythonArgs @loginArgs 2>&1)
  $loginCode = $LASTEXITCODE
  $loginJson = ConvertFrom-JsonLines $loginOutput
  if ($loginCode -ne 0) {
    $message = if ($loginJson -and $loginJson.message) {
      [string]$loginJson.message
    } else {
      "Ziniao login is not complete."
    }
    Write-SetupResult ([ordered]@{
      ok = $false
      method = "setup_ziniao"
      error = if ($loginJson -and $loginJson.error) { [string]$loginJson.error } else { "ziniao_login_check_failed" }
      message = $message
      login_check = $loginJson
      raw_output = if ($loginJson) { $null } else { $loginOutput }
      next_step = "Complete login in the foregrounded Ziniao window, then run .\setup-ziniao.ps1 -AllowGuiMouse again or ask Codex to open the store again."
    }) $loginCode
  }

  if (!$Json) {
    Write-Host "Ziniao passed the login-page check. Reading local Ziniao shop list..."
  }
} elseif (!$Json) {
  Write-Host "Checking Ziniao through non-mouse WebDriver/API only. This will not foreground Ziniao or move the mouse."
  Write-Host ("Waiting up to {0} seconds for an already logged-in local Ziniao session." -f $LoginTimeoutSeconds)
}

if (!$AllowGuiMouse) {
  $userDataInUseBeforeSync = Test-WebDriverUserDataInUse
  if ($userDataInUseBeforeSync) {
    Write-SetupResult ([ordered]@{
      ok = $false
      method = "setup_ziniao"
      error = "ziniao_webdriver_user_data_in_use"
      message = "普通紫鸟正在占用 WebDriver 用户目录，后台 WebDriver 不能同时复用这个登录目录。"
      login_check = $loginJson
      webdriver_user_data_dir = Get-WebDriverUserDataDir
      webdriver_user_data_in_use = $true
      next_step = "请先手动退出普通紫鸟窗口/托盘，再运行 .\setup-ziniao.ps1；这个流程不会抢鼠标。"
    }) 4
  }
}

$syncTimeoutSeconds = 15
$syncLoginTimeoutSeconds = [Math]::Min([Math]::Max(3, $LoginTimeoutSeconds), 120)
$syncArgs = @(
  $syncScript,
  "--out", $Out,
  "--json",
  "--timeout", ([string]$syncTimeoutSeconds),
  "--login-timeout", ([string]$syncLoginTimeoutSeconds)
)
if ($DryRun) {
  $syncArgs += "--dry-run"
}
if ($AllowGuiMouse) {
  $syncArgs += "--allow-visible-client"
}

$syncOutput = @(& $pythonExe @pythonArgs @syncArgs 2>&1)
$syncCode = $LASTEXITCODE
$syncJson = ConvertFrom-JsonLines $syncOutput
if ($syncCode -ne 0) {
  $message = if ($syncJson -and $syncJson.message) {
    [string]$syncJson.message
  } else {
    "Ziniao is open, but no local shop list was returned."
  }
  $userDataInUse = Test-WebDriverUserDataInUse
  $nextStep = if (!$AllowGuiMouse -and $userDataInUse) {
    "普通紫鸟正在占用 WebDriver 用户目录。请先退出普通紫鸟窗口/托盘，再运行 .\setup-ziniao.ps1；这个流程仍然不会抢鼠标。"
  } elseif ($AllowGuiMouse) {
    "Confirm this Ziniao account can see store browsers. If login just completed, restart Ziniao and run .\setup-ziniao.ps1 -AllowGuiMouse again."
  } else {
    "Open and log in to Ziniao manually, then rerun .\setup-ziniao.ps1. If you accept foreground window/mouse control, rerun .\setup-ziniao.ps1 -AllowGuiMouse."
  }
  Write-SetupResult ([ordered]@{
    ok = $false
    method = "setup_ziniao"
    error = if ($syncJson -and $syncJson.error) { [string]$syncJson.error } else { "ziniao_shop_sync_failed" }
    message = $message
    login_check = $loginJson
    sync = $syncJson
    webdriver_user_data_dir = Get-WebDriverUserDataDir
    webdriver_user_data_in_use = [bool]$userDataInUse
    raw_output = if ($syncJson) { $null } else { $syncOutput }
    next_step = $nextStep
  }) $syncCode
}

$shopsCount = if ($syncJson -and $syncJson.shops_count -ne $null) { [int]$syncJson.shops_count } else { $null }
Write-SetupResult ([ordered]@{
  ok = $true
  method = "setup_ziniao"
  message = "Ziniao is ready. Codex can now open local Ziniao stores by store keyword."
  shops_count = $shopsCount
  out = $Out
  dry_run = [bool]$DryRun
  login_check = $loginJson
  sync = $syncJson
  allow_gui_mouse = [bool]$AllowGuiMouse
  next_step = "Restart Codex, then say: open <store keyword> operations/overview/orders/ads data."
}) 0
