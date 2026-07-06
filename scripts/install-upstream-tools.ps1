param(
  [switch]$SkipPythonCli,
  [switch]$SkipNodePackages,
  [switch]$SkipVibeSeller,
  [switch]$SkipPlaywright,
  [switch]$NoPathUpdate,
  [string]$NpmPrefix = "",
  [string]$LocalStateRoot = "",
  [string]$PythonCommand = ""
)

$ErrorActionPreference = "Stop"

$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
. (Join-Path $PSScriptRoot "path-utils.ps1")
$configPath = Join-Path $root "ziniao.local.json"
if (!$LocalStateRoot -and (Test-Path -LiteralPath $configPath)) {
  try {
    $existingConfig = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    if ($existingConfig.local_state_root) {
      $LocalStateRoot = Resolve-ZiniaoOpsRepoPath $root ([string]$existingConfig.local_state_root)
    }
  } catch {
  }
}
if (!$LocalStateRoot) {
  $LocalStateRoot = Join-Path $root ".ziniao-ops"
}
$localState = Resolve-ZiniaoOpsRepoPath $root $LocalStateRoot
$toolsRoot = Join-Path $localState "tools"
$localBin = Join-Path $localState "bin"
$tempRoot = Join-Path $localState "tmp"
$pipCache = Join-Path $localState "pip-cache"
$ziniaoCliVenv = Join-Path $toolsRoot "ziniao-cli-venv"
$vibeVenv = Join-Path $toolsRoot "vibe-seller-venv"
$playwrightBrowsers = Join-Path $toolsRoot "playwright-browsers"

function Ensure-Directory([string]$Path) {
  if (!(Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
  }
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

function Invoke-Checked {
  param(
    [string]$FilePath,
    [string[]]$Arguments
  )
  Write-Host ("> {0} {1}" -f $FilePath, ($Arguments -join " "))
  & $FilePath @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "Command failed with exit code $LASTEXITCODE`: $FilePath"
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
  throw "Python 3 was not found. Install Python 3 first."
}

function Add-UserPathEntry([string]$PathEntry) {
  if ($NoPathUpdate -or !$PathEntry) { return }
  $current = [Environment]::GetEnvironmentVariable("Path", "User")
  $entries = @()
  if ($current) {
    $entries = $current -split ";" | Where-Object { $_ }
  }
  $already = $false
  foreach ($entry in $entries) {
    if ($entry.TrimEnd("\") -ieq $PathEntry.TrimEnd("\")) {
      $already = $true
      break
    }
  }
  if (!$already) {
    $newPath = if ($current) { "$current;$PathEntry" } else { $PathEntry }
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
  }
  if (($env:Path -split ";") -notcontains $PathEntry) {
    $env:Path = "$env:Path;$PathEntry"
  }
}

function Get-PythonUserScripts([hashtable]$Python) {
  $result = (& $Python.File @($Python.PrefixArgs + @("-m", "site", "--user-base")) 2>$null | Select-Object -First 1)
  if ($LASTEXITCODE -eq 0 -and $result) {
    return (Join-Path $result.Trim() "Scripts")
  }
  if ($env:APPDATA) {
    return (Join-Path $env:APPDATA "Python\Python312\Scripts")
  }
  return ""
}

function Ensure-NpmPrefix {
  if ($NpmPrefix) {
    $resolved = Resolve-ZiniaoOpsRepoPath $root $NpmPrefix
    Ensure-Directory $resolved
    return $resolved
  }

  $fallback = Join-Path $localState "npm-global"
  Ensure-Directory $fallback
  return $fallback
}

function Clear-ProjectNpmPrefixConfig([string]$ProjectPrefix) {
  if (!$ProjectPrefix) { return }
  try {
    $configured = (& npm config get prefix --location=user 2>$null | Select-Object -First 1)
    if (!$configured) { return }
    $configuredFull = [System.IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($configured.Trim())).TrimEnd("\")
    $projectFull = [System.IO.Path]::GetFullPath($ProjectPrefix).TrimEnd("\")
    if ($configuredFull -ieq $projectFull) {
      Invoke-Checked -FilePath "npm" -Arguments @("config", "delete", "prefix", "--location=user")
    }
  } catch {
  }
}

Ensure-Directory $localState
Ensure-Directory $toolsRoot
Ensure-Directory $localBin
Ensure-Directory $tempRoot
Ensure-Directory $pipCache

$env:TEMP = $tempRoot
$env:TMP = $tempRoot
$env:PIP_CACHE_DIR = $pipCache
$env:PLAYWRIGHT_BROWSERS_PATH = $playwrightBrowsers

Write-Host "Installing optional upstream tools for ziniao-ops"
Write-Host "Root: $root"
Write-Host "Local tools: $toolsRoot"

$python = $null
if (!$SkipPythonCli -or !$SkipVibeSeller) {
  $python = Resolve-PythonCommand
}

if (!$SkipPythonCli) {
  if (!(Test-Path -LiteralPath (Join-Path $ziniaoCliVenv "Scripts\python.exe"))) {
    Invoke-Checked -FilePath $python.File -Arguments @($python.PrefixArgs + @("-m", "venv", $ziniaoCliVenv))
  }
  $ziniaoPython = Join-Path $ziniaoCliVenv "Scripts\python.exe"
  Invoke-Checked -FilePath $ziniaoPython -Arguments @("-m", "pip", "install", "--upgrade", "pip")
  Invoke-Checked -FilePath $ziniaoPython -Arguments @("-m", "pip", "install", "--upgrade", "ziniao")

  $ziniaoExe = Join-Path $ziniaoCliVenv "Scripts\ziniao.exe"
  $ziniaoPsWrapper = Join-Path $localBin "ziniao.ps1"
  $ziniaoCmdWrapper = Join-Path $localBin "ziniao.cmd"
  $ziniaoPsText = @"
& "$ziniaoExe" @args
exit `$LASTEXITCODE
"@
  Set-Content -LiteralPath $ziniaoPsWrapper -Value $ziniaoPsText -Encoding UTF8
  $ziniaoCmdText = @"
@echo off
"$ziniaoExe" %*
exit /b %ERRORLEVEL%
"@
  Set-Content -LiteralPath $ziniaoCmdWrapper -Value $ziniaoCmdText -Encoding ASCII
  $pythonScripts = $localBin
  Add-UserPathEntry $localBin
}

if (!$SkipNodePackages) {
  $npm = Get-Command "npm" -ErrorAction SilentlyContinue
  if (!$npm) {
    throw "npm was not found. Install Node.js first, or rerun with -SkipNodePackages."
  }
  $resolvedNpmPrefix = Ensure-NpmPrefix
  Clear-ProjectNpmPrefixConfig $resolvedNpmPrefix
  $env:npm_config_prefix = $resolvedNpmPrefix
  $env:npm_config_cache = Join-Path $localState "npm-cache"
  Ensure-Directory $env:npm_config_cache
  Invoke-Checked -FilePath "npm" -Arguments @("install", "-g", "--prefix", $resolvedNpmPrefix, "@ww-ai-lab/auto-ziniao", "@browsermcp/mcp")
  Add-UserPathEntry $resolvedNpmPrefix
}

if (!$SkipVibeSeller) {
  if (!(Test-Path -LiteralPath (Join-Path $vibeVenv "Scripts\python.exe"))) {
    Invoke-Checked -FilePath $python.File -Arguments @($python.PrefixArgs + @("-m", "venv", $vibeVenv))
  }

  $venvPython = Join-Path $vibeVenv "Scripts\python.exe"
  Invoke-Checked -FilePath $venvPython -Arguments @("-m", "pip", "install", "--upgrade", "pip")
  Invoke-Checked -FilePath $venvPython -Arguments @("-m", "pip", "install", "--upgrade", "vibe-seller")

  if (!$SkipPlaywright) {
    Invoke-Checked -FilePath $venvPython -Arguments @("-m", "playwright", "install", "chromium")
  }

  $vibeExe = Join-Path $vibeVenv "Scripts\vibe-seller.exe"
  $psWrapper = Join-Path $localBin "vibe-seller.ps1"
  $cmdWrapper = Join-Path $localBin "vibe-seller.cmd"

  $wrapperText = @"
`$env:PLAYWRIGHT_BROWSERS_PATH = "$playwrightBrowsers"
& "$vibeExe" @args
exit `$LASTEXITCODE
"@
  Set-Content -LiteralPath $psWrapper -Value $wrapperText -Encoding UTF8

  $cmdText = @"
@echo off
set "PLAYWRIGHT_BROWSERS_PATH=$playwrightBrowsers"
"$vibeExe" %*
exit /b %ERRORLEVEL%
"@
  Set-Content -LiteralPath $cmdWrapper -Value $cmdText -Encoding ASCII
  Add-UserPathEntry $localBin
}

Update-LocalConfig @{
  local_state_root = $localState
  npm_prefix = if ($resolvedNpmPrefix) { $resolvedNpmPrefix } else { $NpmPrefix }
  python_user_scripts = if ($pythonScripts) { $pythonScripts } else { "" }
  ziniao_cli_path = Join-Path $localBin "ziniao.ps1"
  vibe_seller_path = Join-Path $localBin "vibe-seller.ps1"
  playwright_browsers_path = $playwrightBrowsers
}

$status = Join-Path $PSScriptRoot "status-upstream-adapters.ps1"
Write-Host ""
Write-Host "Optional upstream tool status:"
powershell -NoProfile -ExecutionPolicy Bypass -File $status

Write-Host ""
Write-Host "Finished optional upstream tool installation."
Write-Host "Notes:"
Write-Host "- auto-ziniao real flows still require ZCLAW_API_KEY and user-approved flow definitions."
Write-Host "- BrowserMCP still requires its Chrome extension and MCP client config."
Write-Host "- Vibe Seller is installed locally, but the long-running service is not started by this script."
