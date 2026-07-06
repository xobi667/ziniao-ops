param(
  [string]$LocalStateRoot = "",
  [string]$PythonCommand = ""
)

$ErrorActionPreference = "Stop"

$packageRoot = (Resolve-Path -LiteralPath $PSScriptRoot).Path
. (Join-Path $packageRoot "scripts\path-utils.ps1")
$configPath = Join-Path $packageRoot "ziniao.local.json"

function Test-IsWindows {
  $var = Get-Variable IsWindows -ErrorAction SilentlyContinue
  if ($var) { return [bool]$var.Value }
  return ($env:OS -eq "Windows_NT")
}

function Ensure-Directory([string]$Path) {
  if (!(Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
  }
}

function Resolve-PythonCommand {
  if ($PythonCommand) {
    return @{ File = $PythonCommand; PrefixArgs = @() }
  }
  $py = Get-Command "py" -ErrorAction SilentlyContinue
  if ($py) {
    return @{ File = $py.Source; PrefixArgs = @("-3") }
  }
  $python = Get-Command "python" -ErrorAction SilentlyContinue
  if ($python) {
    return @{ File = $python.Source; PrefixArgs = @() }
  }
  throw "Python 3 was not found. Install Python 3 first, then rerun this script."
}

function Update-LocalConfig([hashtable]$Values) {
  $cfg = [ordered]@{}
  if (Test-Path -LiteralPath $configPath) {
    try {
      $existing = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
      foreach ($prop in $existing.PSObject.Properties) {
        $cfg[$prop.Name] = $prop.Value
      }
    } catch {
    }
  }
  foreach ($key in $Values.Keys) {
    $cfg[$key] = $Values[$key]
  }
  if (!$cfg.Contains("webdriver_port")) { $cfg["webdriver_port"] = 16851 }
  if (!$cfg.Contains("client_path")) { $cfg["client_path"] = "" }
  if (!$cfg.Contains("note")) { $cfg["note"] = "Local-only config. Do not store passwords, tokens, cookies, or verification codes here." }
  $cfg | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $configPath -Encoding UTF8
}

if (!(Test-IsWindows)) {
  Write-Host "pywinauto is Windows-only. Lazada GUI precision opening requires Windows."
  exit 1
}

if (!$LocalStateRoot -and (Test-Path -LiteralPath $configPath)) {
  try {
    $cfg = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    if ($cfg.local_state_root) {
      $LocalStateRoot = Resolve-ZiniaoOpsRepoPath $packageRoot ([string]$cfg.local_state_root)
    }
  } catch {
  }
}
if (!$LocalStateRoot) {
  $LocalStateRoot = Join-Path $packageRoot ".ziniao-ops"
}

$localState = Resolve-ZiniaoOpsRepoPath $packageRoot $LocalStateRoot
$toolsRoot = Join-Path $localState "tools"
$venvRoot = Join-Path $toolsRoot "python-venv"
$tmpRoot = Join-Path $localState "tmp"
$pipCache = Join-Path $localState "pip-cache"

Ensure-Directory $toolsRoot
Ensure-Directory $tmpRoot
Ensure-Directory $pipCache

$env:TEMP = $tmpRoot
$env:TMP = $tmpRoot
$env:PIP_CACHE_DIR = $pipCache

$python = Resolve-PythonCommand
if (!(Test-Path -LiteralPath (Join-Path $venvRoot "Scripts\python.exe"))) {
  & $python.File @($python.PrefixArgs + @("-m", "venv", $venvRoot))
  if ($LASTEXITCODE -ne 0) { throw "Failed to create local Python venv: $venvRoot" }
}

$venvPython = Join-Path $venvRoot "Scripts\python.exe"
& $venvPython -m pip install --upgrade pip
if ($LASTEXITCODE -ne 0) { throw "Failed to upgrade pip in local Python venv." }

& $venvPython -m pip install --upgrade pywinauto
if ($LASTEXITCODE -ne 0) { throw "Failed to install pywinauto in local Python venv." }

Update-LocalConfig @{
  local_state_root = $localState
  python_path = $venvPython
  python_venv = $venvRoot
}

Write-Host "Installed local Python runtime dependency: pywinauto"
Write-Host "Python path: $venvPython"
