[CmdletBinding(PositionalBinding = $false)]
param(
  [switch]$Json
)

$ErrorActionPreference = "Stop"
$invokeScript = Join-Path $PSScriptRoot "invoke-xinjian-ui-action.ps1"
$testUrl = "https://erp.xinjianerp.com/ad/group-detail"

function U([int[]]$Codepoints) {
  return -join ($Codepoints | ForEach-Object { [char]$_ })
}

function Add-Failure {
  param(
    [System.Collections.Generic.List[object]]$Failures,
    [string]$Message
  )
  [void]$Failures.Add($Message)
}

function Invoke-Action {
  param(
    [string]$Intent,
    [int]$Port = 0,
    [switch]$Execute,
    [switch]$AllowWrite
  )
  $argsList = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", $invokeScript,
    "-Intent", $Intent,
    "-Url", $testUrl,
    "-Json"
  )
  if ($Port -gt 0) { $argsList += @("-Port", [string]$Port) }
  if ($Execute) { $argsList += "-Execute" }
  if ($AllowWrite) { $argsList += "-AllowWrite" }
  $raw = @(& powershell @argsList 2>&1)
  $exitCode = $LASTEXITCODE
  $parsed = $null
  try {
    $parsed = ($raw | Out-String | ConvertFrom-Json)
  } catch {
    return [pscustomobject]@{
      ok = $false
      exit_code = $exitCode
      parse_error = $_.Exception.Message
      raw = ($raw | Out-String).Trim()
    }
  }
  return [pscustomobject]@{
    ok = $true
    exit_code = $exitCode
    payload = $parsed
  }
}

$textModifyConfirm = U @(0x4fee, 0x6539, 0x786e, 0x5b9a)
$expectedModifyConfirmActionId = "dialog.ad.group.detail.dialog_button.{0}.{1}" -f (U @(0x4fee, 0x6539)), (U @(0x786e, 0x5b9a))
$cases = @(
  [pscustomobject]@{
    name = "dry_run_write_requires_confirmation_and_follow_up"
    intent = $textModifyConfirm
    port = 65535
    execute = $false
    allow_write = $false
    expected_exit = 0
    expected_mode = "dry_run"
    expected_can_execute = $false
    expected_confirmation_required = $true
    expected_next_action = "rerun_with_execute_allow_write_after_explicit_confirmation"
  },
  [pscustomobject]@{
    name = "execute_write_without_allow_is_blocked_with_follow_up"
    intent = $textModifyConfirm
    port = 65535
    execute = $true
    allow_write = $false
    expected_exit = 3
    expected_mode = "blocked_by_safety"
    expected_can_execute = $false
    expected_confirmation_required = $true
    expected_next_action = "rerun_with_execute_allow_write_after_explicit_confirmation"
  },
  [pscustomobject]@{
    name = "dry_run_write_with_allow_prepares_verify_follow_up"
    intent = $textModifyConfirm
    port = 65535
    execute = $false
    allow_write = $true
    expected_exit = 0
    expected_mode = "dry_run"
    expected_can_execute = $true
    expected_confirmation_required = $false
    expected_next_action = "run_with_execute_allow_write_after_explicit_confirmation"
  }
)

$results = New-Object System.Collections.Generic.List[object]
$failures = New-Object System.Collections.Generic.List[object]

foreach ($case in $cases) {
  $result = Invoke-Action -Intent $case.intent -Port ([int]$case.port) -Execute:([bool]$case.execute) -AllowWrite:([bool]$case.allow_write)
  $caseFailures = New-Object System.Collections.Generic.List[object]
  if (!$result.ok) {
    Add-Failure -Failures $caseFailures -Message ("invoke output was not JSON: {0}" -f $result.raw)
  } else {
    if ([int]$result.exit_code -ne [int]$case.expected_exit) {
      Add-Failure -Failures $caseFailures -Message ("exit expected {0}, got {1}" -f $case.expected_exit, $result.exit_code)
    }
    if ([string]$result.payload.mode -ne [string]$case.expected_mode) {
      Add-Failure -Failures $caseFailures -Message ("mode expected '{0}', got '{1}'" -f $case.expected_mode, $result.payload.mode)
    }
    if ([string]$result.payload.plan.action.id -ne $expectedModifyConfirmActionId) {
      Add-Failure -Failures $caseFailures -Message ("action id expected {0}, got '{1}'" -f $expectedModifyConfirmActionId, $result.payload.plan.action.id)
    }
    if ([string]$result.payload.plan.safety_mode -ne "confirmation_required_write") {
      Add-Failure -Failures $caseFailures -Message ("safety mode expected confirmation_required_write, got '{0}'" -f $result.payload.plan.safety_mode)
    }
    if ([bool]$result.payload.plan.can_execute -ne [bool]$case.expected_can_execute) {
      Add-Failure -Failures $caseFailures -Message ("can_execute expected {0}, got {1}" -f $case.expected_can_execute, $result.payload.plan.can_execute)
    }
    if ([string]$result.payload.post_execute.kind -ne "write_confirmation_follow_up") {
      Add-Failure -Failures $caseFailures -Message ("post_execute.kind expected write_confirmation_follow_up, got '{0}'" -f $result.payload.post_execute.kind)
    }
    if ([bool]$result.payload.post_execute.confirmation_required -ne [bool]$case.expected_confirmation_required) {
      Add-Failure -Failures $caseFailures -Message ("post_execute.confirmation_required expected {0}, got {1}" -f $case.expected_confirmation_required, $result.payload.post_execute.confirmation_required)
    }
    if ([string]$result.payload.post_execute.next_action -ne [string]$case.expected_next_action) {
      Add-Failure -Failures $caseFailures -Message ("post_execute.next_action expected '{0}', got '{1}'" -f $case.expected_next_action, $result.payload.post_execute.next_action)
    }
    if ([string]$result.payload.post_execute.after_success.primary.script -ne "scripts\list-xinjian-page-actions.ps1") {
      Add-Failure -Failures $caseFailures -Message ("after_success.primary.script expected scripts\list-xinjian-page-actions.ps1, got '{0}'" -f $result.payload.post_execute.after_success.primary.script)
    }
    if ([string]$result.payload.post_execute.after_success.fallback.script -ne "scripts\learn-xinjian-current-page.ps1") {
      Add-Failure -Failures $caseFailures -Message ("after_success.fallback.script expected scripts\learn-xinjian-current-page.ps1, got '{0}'" -f $result.payload.post_execute.after_success.fallback.script)
    }
  }

  $caseOk = ($caseFailures.Count -eq 0)
  if (!$caseOk) {
    foreach ($failure in $caseFailures) {
      Add-Failure -Failures $failures -Message ("{0}: {1}" -f $case.name, $failure)
    }
  }
  [void]$results.Add([ordered]@{
    name = $case.name
    ok = $caseOk
    failures = @($caseFailures.ToArray())
  })
}

$payload = [ordered]@{
  ok = ($failures.Count -eq 0)
  cases = @($results.ToArray())
  failures = @($failures.ToArray())
}

if ($Json) {
  $payload | ConvertTo-Json -Depth 12
} else {
  if ($payload.ok) {
    Write-Host "Xinjian write action planning tests passed."
  } else {
    Write-Host "Xinjian write action planning tests failed:"
    foreach ($failure in $failures) { Write-Host ("- {0}" -f $failure) }
  }
}

if (!$payload.ok) { exit 1 }
