$ErrorActionPreference = "Continue"

$packageRoot = (Resolve-Path -LiteralPath $PSScriptRoot).Path
. (Join-Path $packageRoot "scripts\path-utils.ps1")
$codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE ".codex" }
$skillRoot = Join-Path $codexHome "skills"
$skillConfigPath = Join-Path $codexHome "ziniao-ops.json"
$previousSkillConfigPath = Join-Path $codexHome "ziniao-seller-ops.json"
$legacySkillConfigPath = Join-Path $codexHome "dianpu-open-store.json"
$shopsPath = Join-Path $packageRoot "shops.json"
$ziniaoConfigPath = Join-Path $packageRoot "ziniao.local.json"
$repairPromptPath = Join-Path $packageRoot "本机适配修复提示词.txt"
$shopsTemplatePath = Join-Path $packageRoot "shops.template.json"
$shopsExamplePath = Join-Path $packageRoot "shops.example.json"
$shopsCsvExamplePath = Join-Path $packageRoot "shops.csv.example"
$publicValidatePath = Join-Path $packageRoot "scripts\validate-public.ps1"
$syncZiniaoPath = Join-Path $packageRoot "scripts\sync-ziniao-shops.py"
$setupZiniaoPath = Join-Path $packageRoot "setup-ziniao.ps1"
$legacySkillBackups = @()
if (Test-Path -LiteralPath $skillRoot) {
  $legacySkillBackups = @(
    Get-ChildItem -LiteralPath $skillRoot -Directory -Filter "ziniao-ops.bak-*" -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }
    Get-ChildItem -LiteralPath $skillRoot -Directory -Filter "ziniao-seller-ops.bak-*" -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }
    Get-ChildItem -LiteralPath $skillRoot -Directory -Filter "dianpu-open-store.bak-*" -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }
  )
}

function Test-IsWindows {
  $var = Get-Variable IsWindows -ErrorAction SilentlyContinue
  if ($var) { return [bool]$var.Value }
  return ($env:OS -eq "Windows_NT")
}

$isWindows = Test-IsWindows

function Test-ZiniaoDesktopExe([string]$Path) {
  if (!$Path -or !(Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
  try {
    $dir = Split-Path -Parent $Path
    if ((Test-Path -LiteralPath (Join-Path $dir "resources.pak")) -or (Test-Path -LiteralPath (Join-Path $dir "resources"))) {
      return $true
    }
    return ((Get-Item -LiteralPath $Path).Length -gt 10000000)
  } catch {
    return $false
  }
}

function Find-ZiniaoExe {
  if (!$isWindows) { return "" }
  $candidates = New-Object System.Collections.Generic.List[string]
  foreach ($envName in @("ZINIAO_CLIENT_PATH", "ZINIAO_PATH")) {
    $value = [Environment]::GetEnvironmentVariable($envName)
    if ($value) { $candidates.Add([Environment]::ExpandEnvironmentVariables($value)) }
  }
  if (Test-Path -LiteralPath $ziniaoConfigPath) {
    try {
      $localConfig = Get-Content -LiteralPath $ziniaoConfigPath -Raw | ConvertFrom-Json
      if ($localConfig.client_path) { $candidates.Add((Resolve-ZiniaoOpsRepoPath $packageRoot ([string]$localConfig.client_path))) }
    } catch {
    }
  }
  foreach ($root in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:LOCALAPPDATA, $env:APPDATA, "C:\", "D:\", "E:\", "F:\")) {
    if (!$root -or !(Test-Path -LiteralPath $root)) { continue }
    foreach ($rel in @("ZiNiao\ziniao.exe", "ZiNiao\ZiNiao.exe", "Ziniao\ziniao.exe", "Ziniao\Ziniao.exe", "紫鸟\ziniao.exe", "紫鸟\ZiNiao.exe")) {
      $candidates.Add((Join-Path $root $rel))
    }
  }
  foreach ($dir in @(
    [Environment]::GetFolderPath("Desktop"),
    [Environment]::GetFolderPath("CommonDesktopDirectory"),
    [Environment]::GetFolderPath("StartMenu"),
    [Environment]::GetFolderPath("CommonStartMenu")
  )) {
    if (!$dir -or !(Test-Path -LiteralPath $dir)) { continue }
    Get-ChildItem -LiteralPath $dir -Recurse -Filter *.lnk -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -match "紫鸟|Ziniao|ZiNiao" } |
      ForEach-Object {
        try {
          $shell = New-Object -ComObject WScript.Shell
          $shortcut = $shell.CreateShortcut($_.FullName)
          if ($shortcut.TargetPath) { $candidates.Add($shortcut.TargetPath) }
        } catch {
        }
      }
  }
  foreach ($candidate in $candidates) {
    if ($candidate -and (Test-ZiniaoDesktopExe $candidate)) {
      return (Resolve-Path -LiteralPath $candidate).Path
    }
  }
  $cmd = Get-Command ziniao.exe -ErrorAction SilentlyContinue
  if ($cmd -and (Test-ZiniaoDesktopExe $cmd.Source)) { return $cmd.Source }
  return ""
}

function Get-PythonCommand {
  if (Test-Path -LiteralPath $ziniaoConfigPath) {
    try {
      $cfg = Get-Content -LiteralPath $ziniaoConfigPath -Raw | ConvertFrom-Json
      if ($cfg.python_path) {
        $pythonPath = Resolve-ZiniaoOpsRepoPath $packageRoot ([string]$cfg.python_path)
        if (Test-Path -LiteralPath $pythonPath -PathType Leaf) { return @($pythonPath) }
      }
      if ($cfg.local_state_root) {
        $venvPython = Join-Path (Resolve-ZiniaoOpsRepoPath $packageRoot ([string]$cfg.local_state_root)) "tools\python-venv\Scripts\python.exe"
        if (Test-Path -LiteralPath $venvPython -PathType Leaf) { return @($venvPython) }
      }
    } catch {
    }
  }
  $defaultVenvPython = Join-Path $packageRoot ".ziniao-ops\tools\python-venv\Scripts\python.exe"
  if (Test-Path -LiteralPath $defaultVenvPython -PathType Leaf) { return @($defaultVenvPython) }
  if (Get-Command python -ErrorAction SilentlyContinue) { return @("python") }
  if (Get-Command py -ErrorAction SilentlyContinue) { return @("py", "-3") }
  return @()
}

$shopsCount = 0
$platformCounts = @{}
if (Test-Path -LiteralPath $shopsPath) {
  try {
    $shopsData = Get-Content -LiteralPath $shopsPath -Raw | ConvertFrom-Json
    $shops = @($shopsData.shops)
    $shopsCount = $shops.Count
    foreach ($platform in @("shopee", "tiktok", "lazada")) {
      $platformCounts[$platform] = @($shops | Where-Object { $_.platform -eq $platform }).Count
    }
  } catch {
  }
}

[array]$python = @(Get-PythonCommand)
$pythonVersion = ""
$pywinautoOk = $false
$canSyncZiniaoShops = $false
$detectedZiniaoShopsCount = 0
$ziniaoSyncError = ""
$ziniaoSyncLoginErrorSeen = $false
$ziniaoSyncStartMode = ""
$ziniaoSyncRawStatus = $null
if ($python.Count -gt 0) {
  try {
    $pythonExe = $python[0]
    $pythonArgs = @()
    if ($python.Count -gt 1) { $pythonArgs = @($python[1..($python.Count - 1)]) }
    $pythonVersion = (& $pythonExe @pythonArgs --version 2>&1 | Out-String).Trim()
    & $pythonExe @pythonArgs -c "import pywinauto" 2>$null
    $pywinautoOk = ($LASTEXITCODE -eq 0)
  } catch {
  }
}

$ziniaoPath = Find-ZiniaoExe
$port = 16851
$webdriverUserDataDir = ""
if (Test-Path -LiteralPath $ziniaoConfigPath) {
  try {
    $localConfig = Get-Content -LiteralPath $ziniaoConfigPath -Raw | ConvertFrom-Json
    if ($localConfig.webdriver_port) { $port = [int]$localConfig.webdriver_port }
    foreach ($prop in @("webdriver_user_data_dir", "user_data_dir")) {
      if (!$webdriverUserDataDir -and $localConfig.PSObject.Properties.Name -contains $prop -and $localConfig.$prop) {
        $webdriverUserDataDir = Resolve-ZiniaoOpsRepoPath $packageRoot ([string]$localConfig.$prop)
      }
    }
  } catch {
  }
}
if (!$webdriverUserDataDir -and $env:APPDATA) {
  $webdriverUserDataDir = Join-Path $env:APPDATA "ziniaobrowser\instances\userdata1"
}

$webdriverUserDataInUse = $false
if ($isWindows -and $webdriverUserDataDir) {
  try {
    $resolvedUserDataDir = if (Test-Path -LiteralPath $webdriverUserDataDir) { (Resolve-Path -LiteralPath $webdriverUserDataDir).Path } else { $webdriverUserDataDir }
    $escapedUserDataDir = [regex]::Escape($resolvedUserDataDir)
    $usingProcesses = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
      Where-Object {
        $_.Name -eq "ziniao.exe" -and
        $_.CommandLine -match "--user-data-dir=.*$escapedUserDataDir" -and
        $_.CommandLine -notmatch "--run_type=web_driver"
      })
    $webdriverUserDataInUse = ($usingProcesses.Count -gt 0)
  } catch {
    $webdriverUserDataInUse = $false
  }
}

$webdriverReachable = $false
try {
  $client = New-Object System.Net.Sockets.TcpClient
  $async = $client.BeginConnect("127.0.0.1", $port, $null, $null)
  $webdriverReachable = $async.AsyncWaitHandle.WaitOne(1000, $false)
  if ($webdriverReachable) { $client.EndConnect($async) }
  $client.Close()
} catch {
  $webdriverReachable = $false
}

if ($python.Count -gt 0 -and (Test-Path -LiteralPath $syncZiniaoPath)) {
  if ($webdriverUserDataInUse -and -not $webdriverReachable) {
    $ziniaoSyncError = "ziniao_webdriver_user_data_in_use"
    $ziniaoSyncStartMode = "blocked_user_data_in_use"
  } else {
  try {
    $pythonExe = $python[0]
    $pythonArgs = @()
    if ($python.Count -gt 1) { $pythonArgs = @($python[1..($python.Count - 1)]) }
    $syncOutput = @(& $pythonExe @pythonArgs $syncZiniaoPath --dry-run --json --timeout 4 --login-timeout 4 2>&1)
    $syncText = ($syncOutput | Out-String).Trim()
    if ($LASTEXITCODE -eq 0 -and $syncText) {
      $syncReport = $syncText | ConvertFrom-Json
      $canSyncZiniaoShops = [bool]$syncReport.ok
      $detectedZiniaoShopsCount = [int]$syncReport.shops_count
      if ($syncReport.start_mode) { $ziniaoSyncStartMode = [string]$syncReport.start_mode }
    } elseif ($syncText) {
      try {
        $syncReport = $syncText | ConvertFrom-Json
        $ziniaoSyncError = [string]$syncReport.error
        $ziniaoSyncLoginErrorSeen = [bool]$syncReport.login_error_seen
        if ($syncReport.start_mode) { $ziniaoSyncStartMode = [string]$syncReport.start_mode }
        if ($syncReport.raw_status) { $ziniaoSyncRawStatus = $syncReport.raw_status }
      } catch {
        $ziniaoSyncError = $syncText
      }
    }
  } catch {
    $ziniaoSyncError = $_.Exception.Message
  }
  }
}

$issues = @()
$nextSteps = @()

if (!$isWindows) {
  $issues += "non_windows_limited"
  $nextSteps += "Ziniao desktop/browser automation is Windows-only. On macOS/Linux/WSL, use this repo for config/templates only, or run opening commands on a Windows machine with Ziniao installed."
}
if (!(Test-Path -LiteralPath $skillConfigPath)) {
  $issues += "skill_config_missing"
  if (Test-Path -LiteralPath $previousSkillConfigPath) {
    $nextSteps += "Legacy ziniao-seller-ops config exists. Run install-codex-skill.ps1 from this package to migrate to ziniao-ops, then restart Codex."
  } elseif (Test-Path -LiteralPath $legacySkillConfigPath) {
    $nextSteps += "Legacy dianpu-open-store config exists. Run install-codex-skill.ps1 from this package to migrate to ziniao-ops, then restart Codex."
  } else {
    $nextSteps += "Run install-codex-skill.ps1 from the extracted ziniao-ops folder, then restart Codex."
  }
}
if (!(Test-Path -LiteralPath $setupZiniaoPath)) {
  $issues += "setup_ziniao_missing"
  $nextSteps += "setup-ziniao.ps1 is missing. Re-download the public package or repair this local ziniao-ops folder."
}
if ($legacySkillBackups.Count -gt 0) {
  $issues += "duplicate_skill_backups_in_skills"
  $nextSteps += "Run install-codex-skill.ps1 again. It will move old ziniao-ops/ziniao-seller-ops/dianpu-open-store backup folders out of the Codex skills folder."
}
if (!(Test-Path -LiteralPath $shopsPath) -or $shopsCount -le 0) {
  if ($canSyncZiniaoShops) {
    $nextSteps += "Local shops cache is empty, but this computer can scan Ziniao. The first open-shop run will auto-generate shops.json."
  } else {
    $issues += "ziniao_shops_unavailable"
    if ($ziniaoSyncLoginErrorSeen) {
      $nextSteps += "Ziniao WebDriver is reachable but reports login-state error. Open/log in to Ziniao manually, then rerun setup-ziniao.ps1. Only use setup-ziniao.ps1 -AllowGuiMouse if foreground window/mouse control is acceptable."
    } elseif ($webdriverUserDataInUse) {
      $nextSteps += "普通紫鸟正在占用 WebDriver 用户目录。要走后台模式，请先退出普通紫鸟窗口/托盘，再运行 setup-ziniao.ps1；不要使用 -AllowGuiMouse。"
    } else {
      $nextSteps += "Run setup-ziniao.ps1 for the non-mouse WebDriver check. Only use setup-ziniao.ps1 -AllowGuiMouse if foreground window/mouse control is acceptable."
    }
  }
}
if ($python.Count -eq 0) {
  $issues += "python_missing"
  $nextSteps += "Install Python 3 and make sure python or py is available in PATH."
}
if ($isWindows -and !$ziniaoPath) {
  $issues += "ziniao_path_not_detected"
  $nextSteps += "Open Ziniao manually, or fill ziniao.local.json client_path with this computer's Ziniao exe path."
}
if ($isWindows -and !$webdriverReachable -and !$canSyncZiniaoShops) {
  $issues += "ziniao_webdriver_not_reachable"
  if ($webdriverUserDataInUse) {
    $issues += "ziniao_webdriver_user_data_in_use"
    $nextSteps += "The configured WebDriver user data directory is already used by normal Ziniao, so the hidden WebDriver process exits before opening the port."
  } else {
    $nextSteps += "For Shopee/TikTok, local Ziniao webdriver/API must be reachable on the configured port after Ziniao login. Run setup-ziniao.ps1 first; add -AllowGuiMouse only if foreground control is acceptable."
  }
}
if ($isWindows -and !$pywinautoOk) {
  $issues += "pywinauto_missing_for_lazada"
  $nextSteps += "If Lazada is needed, run install-python-deps.ps1 once on this computer."
}
if ($issues.Count -eq 0) {
  $nextSteps += "Local checks passed. Restart Codex if the skill was just installed, then ask Codex to open a store."
} else {
  $nextSteps += "If these steps do not fit this computer, ask the local Codex to follow 本机适配修复提示词.txt and repair only this ziniao-ops package."
}

$report = [ordered]@{
  ok = ($issues.Count -eq 0)
  ready_for_shopee_tiktok = ($isWindows -and (Test-Path -LiteralPath $skillConfigPath) -and (($shopsCount -gt 0) -or $canSyncZiniaoShops) -and $python.Count -gt 0 -and ($webdriverReachable -or $canSyncZiniaoShops))
  ready_for_lazada = ($isWindows -and (Test-Path -LiteralPath $skillConfigPath) -and (($shopsCount -gt 0) -or $canSyncZiniaoShops) -and $python.Count -gt 0 -and $pywinautoOk)
  is_windows = $isWindows
  os = [System.Environment]::OSVersion.VersionString
  powershell_version = $PSVersionTable.PSVersion.ToString()
  powershell_edition = $PSVersionTable.PSEdition
  package_root = $packageRoot
  codex_home = $codexHome
  skill_config_exists = (Test-Path -LiteralPath $skillConfigPath)
  previous_skill_config_exists = (Test-Path -LiteralPath $previousSkillConfigPath)
  legacy_skill_config_exists = (Test-Path -LiteralPath $legacySkillConfigPath)
  duplicate_skill_backups_in_skills = $legacySkillBackups
  shops_json_exists = (Test-Path -LiteralPath $shopsPath)
  shops_template_exists = (Test-Path -LiteralPath $shopsTemplatePath)
  shops_example_exists = (Test-Path -LiteralPath $shopsExamplePath)
  shops_csv_example_exists = (Test-Path -LiteralPath $shopsCsvExamplePath)
  shops_count = $shopsCount
  platform_counts = $platformCounts
  python_command = ($python -join " ")
  python_version = $pythonVersion
  pywinauto_installed = $pywinautoOk
  ziniao_config_exists = (Test-Path -LiteralPath $ziniaoConfigPath)
  repair_prompt_exists = (Test-Path -LiteralPath $repairPromptPath)
  repair_prompt_path = $repairPromptPath
  public_validate_exists = (Test-Path -LiteralPath $publicValidatePath)
  setup_ziniao_exists = (Test-Path -LiteralPath $setupZiniaoPath)
  sync_ziniao_script_exists = (Test-Path -LiteralPath $syncZiniaoPath)
  git_available = [bool](Get-Command git -ErrorAction SilentlyContinue)
  codex_cli_available = [bool](Get-Command codex -ErrorAction SilentlyContinue)
  detected_ziniao_path = $ziniaoPath
  webdriver_port = $port
  webdriver_user_data_dir = $webdriverUserDataDir
  webdriver_user_data_in_use = $webdriverUserDataInUse
  webdriver_port_reachable = $webdriverReachable
  can_sync_ziniao_shops = $canSyncZiniaoShops
  detected_ziniao_shops_count = $detectedZiniaoShopsCount
  ziniao_sync_error = $ziniaoSyncError
  ziniao_sync_login_error_seen = $ziniaoSyncLoginErrorSeen
  ziniao_sync_start_mode = $ziniaoSyncStartMode
  ziniao_sync_raw_status = $ziniaoSyncRawStatus
  issues = $issues
  next_steps = $nextSteps
  notes = @(
    "Full Ziniao automation is intended for Windows desktops with Ziniao installed.",
    "setup-ziniao.ps1 is the first-run readiness step. By default it uses non-mouse WebDriver/API checks; -AllowGuiMouse enables foreground GUI login handoff.",
    "shops.json is now a local cache. If it is missing, open-shop.ps1 can generate it from the local Ziniao browser list.",
    "If can_sync_ziniao_shops is false, open and log in to Ziniao, or set ziniao.local.json client_path.",
    "Lazada precise opening needs pywinauto_installed=true.",
    "Store backend access still depends on this computer's local seller login state.",
    "For local-machine adaptation, use 本机适配修复提示词.txt with the employee's own Codex."
  )
}

$report | ConvertTo-Json -Depth 8
