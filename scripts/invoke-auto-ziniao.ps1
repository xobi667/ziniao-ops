param(
  [ValidateSet("help", "list", "validate", "run", "retry", "history", "stats", "heals", "cron")]
  [string]$Action = "help",
  [string]$FlowId = "",
  [string[]]$Param = @(),
  [switch]$NoHeal,
  [switch]$VerboseRun,
  [switch]$AllowExternalRunner,
  [switch]$Json
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
  $localBin = Join-Path (Get-LocalStateRoot) "bin"
  foreach ($ext in @(".ps1", ".cmd", ".exe", ".bat", "")) {
    $candidate = Join-Path $localBin ($Name + $ext)
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
      return (Resolve-Path -LiteralPath $candidate).Path
    }
  }
  $npmPrefix = ""
  try {
    $cfgPath = Join-Path $root "ziniao.local.json"
    if (Test-Path -LiteralPath $cfgPath) {
      $cfg = Get-Content -LiteralPath $cfgPath -Raw | ConvertFrom-Json
      if ($cfg.npm_prefix) { $npmPrefix = Resolve-ZiniaoOpsRepoPath $root ([string]$cfg.npm_prefix) }
    }
  } catch {
  }
  if ($npmPrefix) {
    foreach ($ext in @(".ps1", ".cmd", ".exe", ".bat", "")) {
      $candidate = Join-Path $npmPrefix ($Name + $ext)
      if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        return (Resolve-Path -LiteralPath $candidate).Path
      }
    }
  }
  $cmd = Get-Command $Name -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  return ""
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

$cmd = Get-ToolPath "auto-ziniao"
if (!$cmd) {
  Write-Result ([ordered]@{
    ok = $false
    error = "auto_ziniao_missing"
    message = "The optional auto-ziniao runner is not installed on this computer."
  }) 3
}

$externalActions = @("run", "retry", "cron")
if ($Action -in $externalActions -and !$AllowExternalRunner) {
  Write-Result ([ordered]@{
    ok = $false
    error = "external_runner_confirmation_required"
    message = "This auto-ziniao action can operate a store flow. Pass -AllowExternalRunner only after the user explicitly asks for this optional route."
    action = $Action
  }) 4
}

foreach ($value in @($FlowId) + @($Param)) {
  if ($value -match "(?i)(password|passwd|pwd|secret|token|cookie|session|private[_-]?key|api[_-]?key)") {
    Write-Result ([ordered]@{
      ok = $false
      error = "secret_like_argument_refused"
      message = "Refusing to pass secret-like arguments to an external auto-ziniao command."
    }) 4
  }
}

$commandArgs = @()
switch ($Action) {
  "help" { $commandArgs = @("--help") }
  "list" { $commandArgs = @("list") }
  "history" { $commandArgs = @("history") }
  "stats" { $commandArgs = @("stats") }
  "heals" { $commandArgs = @("heals") }
  "cron" { $commandArgs = @("cron") }
  "validate" {
    if (!$FlowId) { Write-Result ([ordered]@{ ok = $false; error = "flow_id_required"; message = "FlowId is required for validate." }) 2 }
    $commandArgs = @("validate", $FlowId)
  }
  "retry" {
    if (!$FlowId) { Write-Result ([ordered]@{ ok = $false; error = "flow_id_required"; message = "FlowId is required for retry." }) 2 }
    $commandArgs = @("retry", $FlowId)
  }
  "run" {
    if (!$FlowId) { Write-Result ([ordered]@{ ok = $false; error = "flow_id_required"; message = "FlowId is required for run." }) 2 }
    $commandArgs = @("run", $FlowId)
    foreach ($pair in @($Param)) {
      if ($pair -notmatch "^[A-Za-z0-9_.-]+=.+" ) {
        Write-Result ([ordered]@{ ok = $false; error = "invalid_param"; message = "Each -Param value must be key=value."; value = $pair }) 2
      }
      $commandArgs += @("-p", $pair)
    }
    if ($VerboseRun) { $commandArgs += "-v" }
    if ($NoHeal) { $commandArgs += "--no-heal" }
  }
}

$joinedArgs = ($commandArgs -join " ")
$output = @()
$exitCode = 0
try {
  $output = @(& $cmd @commandArgs 2>&1)
  $exitCode = $LASTEXITCODE
} catch {
  Write-Result ([ordered]@{
    ok = $false
    error = $_.Exception.Message
    command = "auto-ziniao $joinedArgs"
  }) 1
}

Write-Result ([ordered]@{
  ok = ($exitCode -eq 0)
  exit_code = $exitCode
  command = "auto-ziniao $joinedArgs"
  output = @($output | ForEach-Object { $_.ToString() })
}) $exitCode
