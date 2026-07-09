param(
  [string]$Root = "",
  [string]$NpmPrefix = "",
  [switch]$NoInstall,
  [switch]$NoPathUpdate,
  [switch]$Json
)

$ErrorActionPreference = "Stop"

if (!$Root) {
  $Root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
} else {
  $Root = (Resolve-Path -LiteralPath $Root).Path
}

. (Join-Path $PSScriptRoot "path-utils.ps1")

$configPath = Join-Path $Root "ziniao.local.json"

function Resolve-RepoPath([string]$Path) {
  if (!$Path) { return "" }
  return Resolve-ZiniaoOpsRepoPath $Root $Path
}

function Get-LocalStateRoot {
  $defaultState = Join-Path $Root ".ziniao-ops"
  if (Test-Path -LiteralPath $configPath) {
    try {
      $cfg = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
      if ($cfg.local_state_root) {
        return Resolve-RepoPath ([string]$cfg.local_state_root)
      }
    } catch {
    }
  }
  return $defaultState
}

function Ensure-Directory([string]$Path) {
  if (!(Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
  }
}

function Add-UserPathEntry([string]$PathEntry) {
  if ($NoPathUpdate -or !$PathEntry) { return $false }
  $current = [Environment]::GetEnvironmentVariable("Path", "User")
  $entries = @()
  if ($current) {
    $entries = $current -split ";" | Where-Object { $_ }
  }
  foreach ($entry in $entries) {
    if ($entry.TrimEnd("\") -ieq $PathEntry.TrimEnd("\")) {
      if (($env:Path -split ";") -notcontains $PathEntry) {
        $env:Path = "$env:Path;$PathEntry"
      }
      return $false
    }
  }
  $newPath = if ($current) { "$current;$PathEntry" } else { $PathEntry }
  [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
  if (($env:Path -split ";") -notcontains $PathEntry) {
    $env:Path = "$env:Path;$PathEntry"
  }
  return $true
}

function Get-NpmPrefix {
  if ($NpmPrefix) {
    $resolved = Resolve-RepoPath $NpmPrefix
    Ensure-Directory $resolved
    return $resolved
  }

  if (Test-Path -LiteralPath $configPath) {
    try {
      $cfg = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
      if ($cfg.npm_prefix) {
        $resolved = Resolve-RepoPath ([string]$cfg.npm_prefix)
        Ensure-Directory $resolved
        return $resolved
      }
    } catch {
    }
  }

  $fallback = Join-Path (Get-LocalStateRoot) "npm-global"
  Ensure-Directory $fallback
  return $fallback
}

function Get-ToolCommand {
  param(
    [string[]]$Names,
    [string[]]$ExtraPaths = @()
  )

  $extensions = @("", ".exe", ".cmd", ".bat", ".ps1")
  foreach ($dir in $ExtraPaths) {
    if (!$dir) { continue }
    foreach ($name in $Names) {
      foreach ($ext in $extensions) {
        $candidate = Join-Path $dir ($name + $ext)
        if (Test-Path -LiteralPath $candidate) {
          return (Resolve-Path -LiteralPath $candidate).Path
        }
      }
    }
  }

  foreach ($name in $Names) {
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
  }

  return ""
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

$prefix = Get-NpmPrefix
$npmCache = Join-Path (Get-LocalStateRoot) "npm-cache"
Ensure-Directory $npmCache
$commandNames = @("chrome-devtools-mcp", "chrome-devtools")
$beforeCommand = Get-ToolCommand -Names $commandNames -ExtraPaths @($prefix)
$npm = Get-Command "npm" -ErrorAction SilentlyContinue
$installed = $false
$pathUpdated = $false
$installOutput = ""
$installExitCode = $null
$errorCode = ""

if (!$beforeCommand -and !$NoInstall) {
  if (!$npm) {
    $errorCode = "npm_missing"
  } else {
    $previousPrefix = $env:npm_config_prefix
    $previousCache = $env:npm_config_cache
    $env:npm_config_prefix = $prefix
    $env:npm_config_cache = $npmCache
    try {
      $raw = @(& npm install -g --prefix $prefix chrome-devtools-mcp 2>&1)
      $installExitCode = $LASTEXITCODE
      $installOutput = ($raw | Out-String).Trim()
      if ($installExitCode -eq 0) {
        $installed = $true
      } else {
        $errorCode = "npm_install_failed"
      }
    } finally {
      $env:npm_config_prefix = $previousPrefix
      $env:npm_config_cache = $previousCache
    }
  }
}

$afterCommand = Get-ToolCommand -Names $commandNames -ExtraPaths @($prefix)
if ($afterCommand) {
  $pathUpdated = Add-UserPathEntry -PathEntry $prefix
  Update-LocalConfig @{
    local_state_root = Get-LocalStateRoot
    npm_prefix = $prefix
    chrome_devtools_mcp_path = $afterCommand
  }
}

$ok = [bool]$afterCommand
$payload = [ordered]@{
  ok = $ok
  package = "chrome-devtools-mcp"
  command = $afterCommand
  command_before = $beforeCommand
  npm = if ($npm) { $npm.Source } else { "" }
  npm_prefix = $prefix
  installed = $installed
  no_install = [bool]$NoInstall
  path_updated = $pathUpdated
  install_exit_code = $installExitCode
  install_output = $installOutput
  error = if ($ok) { "" } elseif ($errorCode) { $errorCode } else { "chrome_devtools_mcp_missing" }
  restart_codex_required = [bool]($installed -or $pathUpdated)
  next_action = if ($ok -and ($installed -or $pathUpdated)) {
    "restart_codex_to_load_chrome_devtools_mcp"
  } elseif ($ok) {
    "chrome_devtools_mcp_available"
  } elseif ($errorCode -eq "npm_missing") {
    "install_node_npm_then_rerun"
  } elseif ($NoInstall) {
    "rerun_without_noinstall_to_install_chrome_devtools_mcp"
  } else {
    "inspect_npm_install_output"
  }
}

if ($Json) {
  $payload | ConvertTo-Json -Depth 8
} else {
  if ($ok) {
    Write-Host "Chrome DevTools MCP is available: $afterCommand"
    if ($payload.restart_codex_required) {
      Write-Host "Restart Codex before expecting the new MCP tool to appear."
    }
  } else {
    Write-Host "Chrome DevTools MCP is not available: $($payload.error)"
  }
}

if (!$ok) { exit 1 }
