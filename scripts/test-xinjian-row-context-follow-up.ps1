[CmdletBinding(PositionalBinding = $false)]
param(
  [switch]$Json
)

$ErrorActionPreference = "Stop"
$invokeScript = Join-Path $PSScriptRoot "invoke-xinjian-ui-action.ps1"
$testUrl = "https://erp.xinjianerp.com/crm/matser/management/highSeas"

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
    [switch]$Execute
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

$textOperationDetail = U @(0x64cd, 0x4f5c, 0x8be6, 0x60c5)
$textFirstRowOperationDetail = (U @(0x7b2c, 0x31, 0x884c)) + $textOperationDetail
$textOperationDelete = U @(0x64cd, 0x4f5c, 0x5220, 0x9664)
$expectedDetailActionId = "row.crm.matser.management.highseas.row_action.{0}.{1}" -f (U @(0x64cd, 0x4f5c)), (U @(0x8be6, 0x60c5))
$expectedDeleteActionId = "row.crm.matser.management.highseas.row_action.{0}.{1}" -f (U @(0x64cd, 0x4f5c)), (U @(0x5220, 0x9664))

$cases = @(
  [pscustomobject]@{
    name = "dry_run_safe_row_action_without_context_gives_follow_up"
    intent = $textOperationDetail
    port = 65535
    execute = $false
    expected_exit = 0
    expected_mode = "dry_run"
    expected_action_id = $expectedDetailActionId
    expected_can_execute = $false
    expected_row_required = $true
    expected_row_provided = $false
    expected_follow_up = $true
    expected_extra_confirmation = $null
  },
  [pscustomobject]@{
    name = "execute_safe_row_action_without_context_is_blocked_with_follow_up"
    intent = $textOperationDetail
    port = 65535
    execute = $true
    expected_exit = 3
    expected_mode = "blocked_by_safety"
    expected_action_id = $expectedDetailActionId
    expected_can_execute = $false
    expected_row_required = $true
    expected_row_provided = $false
    expected_follow_up = $true
    expected_extra_confirmation = $null
  },
  [pscustomobject]@{
    name = "dry_run_safe_row_action_with_inferred_index_has_no_follow_up"
    intent = $textFirstRowOperationDetail
    port = 65535
    execute = $false
    expected_exit = 0
    expected_mode = "dry_run"
    expected_action_id = $expectedDetailActionId
    expected_can_execute = $true
    expected_row_required = $true
    expected_row_provided = $true
    expected_row_source = "intent_row_index"
    expected_row_index = 1
    expected_follow_up = $false
  },
  [pscustomobject]@{
    name = "dry_run_write_row_action_without_context_notes_write_confirmation"
    intent = $textOperationDelete
    port = 65535
    execute = $false
    expected_exit = 0
    expected_mode = "dry_run"
    expected_action_id = $expectedDeleteActionId
    expected_can_execute = $false
    expected_row_required = $true
    expected_row_provided = $false
    expected_follow_up = $true
    expected_extra_confirmation = "allow_write"
  }
)

$results = New-Object System.Collections.Generic.List[object]
$failures = New-Object System.Collections.Generic.List[object]

foreach ($case in $cases) {
  $result = Invoke-Action -Intent $case.intent -Port ([int]$case.port) -Execute:([bool]$case.execute)
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
    if ([string]$result.payload.plan.action.id -ne [string]$case.expected_action_id) {
      Add-Failure -Failures $caseFailures -Message ("action id expected '{0}', got '{1}'" -f $case.expected_action_id, $result.payload.plan.action.id)
    }
    if ([bool]$result.payload.plan.can_execute -ne [bool]$case.expected_can_execute) {
      Add-Failure -Failures $caseFailures -Message ("can_execute expected {0}, got {1}" -f $case.expected_can_execute, $result.payload.plan.can_execute)
    }
    if ([bool]$result.payload.plan.row_context.required -ne [bool]$case.expected_row_required) {
      Add-Failure -Failures $caseFailures -Message ("row_context.required expected {0}, got {1}" -f $case.expected_row_required, $result.payload.plan.row_context.required)
    }
    if ([bool]$result.payload.plan.row_context.provided -ne [bool]$case.expected_row_provided) {
      Add-Failure -Failures $caseFailures -Message ("row_context.provided expected {0}, got {1}" -f $case.expected_row_provided, $result.payload.plan.row_context.provided)
    }
    if ($case.PSObject.Properties.Name -contains "expected_row_source") {
      if ([string]$result.payload.plan.row_context.source -ne [string]$case.expected_row_source) {
        Add-Failure -Failures $caseFailures -Message ("row_context.source expected '{0}', got '{1}'" -f $case.expected_row_source, $result.payload.plan.row_context.source)
      }
    }
    if ($case.PSObject.Properties.Name -contains "expected_row_index") {
      if ([int]$result.payload.plan.row_context.row_index -ne [int]$case.expected_row_index) {
        Add-Failure -Failures $caseFailures -Message ("row_context.row_index expected {0}, got {1}" -f $case.expected_row_index, $result.payload.plan.row_context.row_index)
      }
    }
    $hasFollowUp = ($null -ne $result.payload.row_context_follow_up -and [string]$result.payload.row_context_follow_up.kind -eq "row_context_required_follow_up")
    if ([bool]$hasFollowUp -ne [bool]$case.expected_follow_up) {
      Add-Failure -Failures $caseFailures -Message ("row_context_follow_up presence expected {0}, got {1}" -f $case.expected_follow_up, $hasFollowUp)
    }
    if ($case.expected_follow_up) {
      if ([string]$result.payload.row_context_follow_up.next_action -ne "rerun_with_row_index_or_row_text") {
        Add-Failure -Failures $caseFailures -Message ("row_context_follow_up.next_action expected rerun_with_row_index_or_row_text, got '{0}'" -f $result.payload.row_context_follow_up.next_action)
      }
      if ([string]$result.payload.row_context_follow_up.rerun_with_row_index.script -ne "scripts\invoke-xinjian-ui-action.ps1") {
        Add-Failure -Failures $caseFailures -Message ("rerun_with_row_index.script expected scripts\invoke-xinjian-ui-action.ps1, got '{0}'" -f $result.payload.row_context_follow_up.rerun_with_row_index.script)
      }
      if ([string]$result.payload.row_context_follow_up.rerun_with_row_text.row_text -ne "[visible row text]") {
        Add-Failure -Failures $caseFailures -Message "rerun_with_row_text.row_text placeholder was not preserved"
      }
      if ([string]$result.payload.row_context_follow_up.additional_confirmation_required -ne [string]$case.expected_extra_confirmation) {
        Add-Failure -Failures $caseFailures -Message ("additional_confirmation_required expected '{0}', got '{1}'" -f $case.expected_extra_confirmation, $result.payload.row_context_follow_up.additional_confirmation_required)
      }
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
    Write-Host "Xinjian row-context follow-up tests passed."
  } else {
    Write-Host "Xinjian row-context follow-up tests failed:"
    foreach ($failure in $failures) { Write-Host ("- {0}" -f $failure) }
  }
}

if (!$payload.ok) { exit 1 }
