param(
  [int]$LoginTimeoutSeconds = 600,
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
    next_step = "Complete login in the foregrounded Ziniao window, then run .\setup-ziniao.ps1 again or ask Codex to open the store again."
  }) $loginCode
}

if (!$Json) {
  Write-Host "Ziniao passed the login-page check. Reading local Ziniao shop list..."
}

$syncTimeoutSeconds = 15
$syncLoginTimeoutSeconds = [Math]::Min([Math]::Max(20, $LoginTimeoutSeconds), 120)
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

$syncOutput = @(& $pythonExe @pythonArgs @syncArgs 2>&1)
$syncCode = $LASTEXITCODE
$syncJson = ConvertFrom-JsonLines $syncOutput
if ($syncCode -ne 0) {
  $message = if ($syncJson -and $syncJson.message) {
    [string]$syncJson.message
  } else {
    "Ziniao is open, but no local shop list was returned."
  }
  Write-SetupResult ([ordered]@{
    ok = $false
    method = "setup_ziniao"
    error = if ($syncJson -and $syncJson.error) { [string]$syncJson.error } else { "ziniao_shop_sync_failed" }
    message = $message
    login_check = $loginJson
    sync = $syncJson
    raw_output = if ($syncJson) { $null } else { $syncOutput }
    next_step = "Confirm this Ziniao account can see store browsers. If login just completed, restart Ziniao and run .\setup-ziniao.ps1 again."
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
  next_step = "Restart Codex, then say: open <store keyword> operations/overview/orders/ads data."
}) 0
