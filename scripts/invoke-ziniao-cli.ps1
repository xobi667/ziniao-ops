param(
  [switch]$AllowExternalCommand,
  [switch]$AllowLongRunning,
  [switch]$Json,
  [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
  [string[]]$CommandArgs = @()
)

$ErrorActionPreference = "Continue"
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
. (Join-Path $PSScriptRoot "path-utils.ps1")

function Get-LocalStateRoot {
  $cfgPath = Join-Path $root "ziniao.local.json"
  if (Test-Path -LiteralPath $cfgPath) {
    try {
      $cfg = Get-Content -LiteralPath $cfgPath -Raw | ConvertFrom-Json
      if ($cfg.local_state_root) {
        return Resolve-ZiniaoOpsRepoPath $root ([string]$cfg.local_state_root)
      }
    } catch {
    }
  }
  return (Join-Path $root ".ziniao-ops")
}

function Get-ToolPath([string]$Name) {
  $localState = Get-LocalStateRoot
  $localBin = Join-Path $localState "bin"
  $ziniaoCliScripts = Join-Path $localState "tools\ziniao-cli-venv\Scripts"
  foreach ($dir in @($ziniaoCliScripts, $localBin)) {
    foreach ($ext in @(".ps1", ".cmd", ".exe", ".bat", "")) {
      $candidate = Join-Path $dir ($Name + $ext)
      if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        return (Resolve-Path -LiteralPath $candidate).Path
      }
    }
  }
  $cmd = Get-Command $Name -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  return ""
}

function Set-ZiniaoCliLocalEnvironment {
  $cfgPath = Join-Path $root "ziniao.local.json"
  if (!(Test-Path -LiteralPath $cfgPath)) { return }
  try {
    $cfg = Get-Content -LiteralPath $cfgPath -Raw | ConvertFrom-Json
    if (!$env:ZINIAO_CLIENT_PATH -and $cfg.client_path) {
      $clientPath = Resolve-ZiniaoOpsRepoPath $root ([string]$cfg.client_path)
      if (Test-Path -LiteralPath $clientPath -PathType Leaf) {
        $env:ZINIAO_CLIENT_PATH = $clientPath
      }
    }
    if (!$env:ZINIAO_SOCKET_PORT -and $cfg.webdriver_port) {
      $env:ZINIAO_SOCKET_PORT = [string]([int]$cfg.webdriver_port)
    }
  } catch {
  }
}

function Write-Result($Object, [int]$Code = 0) {
  if ($Json) {
    $Object | ConvertTo-Json -Depth 8
  } else {
    if ($Object.message) { Write-Host $Object.message }
    if ($Object.command) { Write-Host ("command: {0}" -f $Object.command) }
    if ($Object.output) { $Object.output | ForEach-Object { Write-Host $_ } }
    if ($Object.error) { Write-Host ("error: {0}" -f $Object.error) }
  }
  exit $Code
}

$cmd = Get-ToolPath "ziniao"
if (!$cmd) {
  Write-Result ([ordered]@{
    ok = $false
    error = "ziniao_cli_missing"
    message = "The optional ziniao CLI is not installed on this computer."
    install_hint = "Install it outside this package only if the user wants the optional CLI/MCP route."
  }) 3
}

Set-ZiniaoCliLocalEnvironment
if ($Json -and !$env:ZINIAO_JSON) {
  $env:ZINIAO_JSON = "1"
}

if (!$CommandArgs -or $CommandArgs.Count -eq 0) {
  $CommandArgs = @("--help")
}

$joinedArgs = ($CommandArgs -join " ")
$firstArg = if ($CommandArgs.Count -gt 0) { [string]$CommandArgs[0] } else { "" }
if ($joinedArgs -match "(?i)(password|passwd|pwd|secret|token|cookie|session|private[_-]?key|api[_-]?key)") {
  Write-Result ([ordered]@{
    ok = $false
    error = "secret_like_argument_refused"
    message = "Refusing to pass secret-like arguments to an external CLI."
  }) 4
}

$helpOnly = (
  ($CommandArgs.Count -eq 1 -and $CommandArgs[0] -in @("--help", "-h", "help", "--version", "-V", "version")) -or
  ($CommandArgs.Count -ge 2 -and $CommandArgs[-1] -in @("--help", "-h", "help"))
)
$longRunningCommand = ($firstArg -match "(?i)^(serve|server|daemon)$")
if ($longRunningCommand -and !$helpOnly -and !$AllowLongRunning) {
  Write-Result ([ordered]@{
    ok = $false
    error = "long_running_command_refused"
    message = "Refusing to start a long-running ziniao command without -AllowLongRunning."
    requested_args = $CommandArgs
  }) 4
}

if (!$helpOnly -and !$AllowExternalCommand) {
  Write-Result ([ordered]@{
    ok = $false
    error = "external_command_confirmation_required"
    message = "Pass -AllowExternalCommand for ziniao CLI store/page commands. The ziniao-ops skill may use this by default for the CLI-first route, but the wrapper keeps this guard for direct manual calls."
    requested_args = $CommandArgs
  }) 4
}

$output = @()
$exitCode = 0
try {
  $output = @(& $cmd @CommandArgs 2>&1)
  $exitCode = $LASTEXITCODE
} catch {
  Write-Result ([ordered]@{
    ok = $false
    error = $_.Exception.Message
    command = "ziniao $joinedArgs"
  }) 1
}

$cliJson = $null
$cliBusinessOk = $true
if ($Json -and $output.Count -gt 0) {
  $text = ($output | Out-String).Trim()
  if ($text) {
    try {
      $cliJson = $text | ConvertFrom-Json
      if ($cliJson.PSObject.Properties.Name -contains "success" -and -not [bool]$cliJson.success) {
        $cliBusinessOk = $false
      } elseif ($cliJson.PSObject.Properties.Name -contains "ok" -and -not [bool]$cliJson.ok) {
        $cliBusinessOk = $false
      }
    } catch {
      $cliJson = $null
    }
  }
}

$wrapperOk = ($exitCode -eq 0 -and $cliBusinessOk)
Write-Result ([ordered]@{
  ok = $wrapperOk
  exit_code = $exitCode
  cli_success = if ($cliJson -and $cliJson.PSObject.Properties.Name -contains "success") { [bool]$cliJson.success } else { $null }
  cli_error = if ($cliJson -and $cliJson.PSObject.Properties.Name -contains "error") { $cliJson.error } else { $null }
  command = "ziniao $joinedArgs"
  output = @($output | ForEach-Object { $_.ToString() })
}) $(if ($wrapperOk) { 0 } elseif ($exitCode -ne 0) { $exitCode } else { 1 })
