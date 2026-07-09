[CmdletBinding(PositionalBinding = $false)]
param(
  [switch]$Json
)

$ErrorActionPreference = "Stop"
$invokeScript = Join-Path $PSScriptRoot "invoke-xinjian-ui-action.ps1"
$testUrl = "https://erp.xinjianerp.com/ad/shop-detail"

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
    "-Json"
  )
  if ($Port -gt 0) {
    $argsList += @("-Url", $testUrl, "-Port", [string]$Port)
  } else {
    $argsList += @("-NoAutoDetectUrl", "-NoAutoOpenLogin")
  }
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

$textAdSpend = U @(0x5e7f, 0x544a, 0x82b1, 0x8d39)
$textFirstRowAdSpend = (U @(0x7b2c, 0x31, 0x884c, 0x20, 0x5e7f, 0x544a, 0x82b1, 0x8d39))
$cases = @(
  [pscustomobject]@{
    name = "dry_run_without_port_blocks_table_read"
    intent = $textAdSpend
    port = 0
    execute = $false
    expected_exit = 0
    expected_mode = "dry_run"
    expected_can_execute = $false
    expected_backend = "none"
  },
  [pscustomobject]@{
    name = "dry_run_with_port_allows_table_read"
    intent = $textAdSpend
    port = 65535
    execute = $false
    expected_exit = 0
    expected_mode = "dry_run"
    expected_can_execute = $true
    expected_backend = "cdp"
  },
  [pscustomobject]@{
    name = "dry_run_with_port_preserves_row_context_for_table_read"
    intent = $textFirstRowAdSpend
    port = 65535
    execute = $false
    expected_exit = 0
    expected_mode = "dry_run"
    expected_can_execute = $true
    expected_backend = "cdp"
    expected_row_required = $false
    expected_row_provided = $true
    expected_row_source = "intent_row_index"
    expected_row_index = 1
  },
  [pscustomobject]@{
    name = "execute_without_port_reports_read_blocker"
    intent = $textAdSpend
    port = 0
    execute = $true
    expected_exit = 3
    expected_mode = "blocked_by_safety"
    expected_can_execute = $false
    expected_backend = "none"
    expected_next_action = "open_or_login_debuggable_xinjian_browser_to_read_table_column"
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
    if ([string]$result.payload.plan.action.type -ne "table_column") {
      Add-Failure -Failures $caseFailures -Message ("action type expected table_column, got '{0}'" -f $result.payload.plan.action.type)
    }
    if ([string]$result.payload.plan.locator_strategy -ne "read_table_column_header") {
      Add-Failure -Failures $caseFailures -Message ("locator strategy expected read_table_column_header, got '{0}'" -f $result.payload.plan.locator_strategy)
    }
    if ([bool]$result.payload.plan.can_execute -ne [bool]$case.expected_can_execute) {
      Add-Failure -Failures $caseFailures -Message ("can_execute expected {0}, got {1}" -f $case.expected_can_execute, $result.payload.plan.can_execute)
    }
    if ([string]$result.payload.plan.execution_backend -ne [string]$case.expected_backend) {
      Add-Failure -Failures $caseFailures -Message ("backend expected '{0}', got '{1}'" -f $case.expected_backend, $result.payload.plan.execution_backend)
    }
    if ($case.PSObject.Properties.Name -contains "expected_next_action") {
      if ([string]$result.payload.next_action -ne [string]$case.expected_next_action) {
        Add-Failure -Failures $caseFailures -Message ("next_action expected '{0}', got '{1}'" -f $case.expected_next_action, $result.payload.next_action)
      }
    }
    if ($case.PSObject.Properties.Name -contains "expected_row_required") {
      if ([bool]$result.payload.plan.row_context.required -ne [bool]$case.expected_row_required) {
        Add-Failure -Failures $caseFailures -Message ("row_context.required expected {0}, got {1}" -f $case.expected_row_required, $result.payload.plan.row_context.required)
      }
    }
    if ($case.PSObject.Properties.Name -contains "expected_row_provided") {
      if ([bool]$result.payload.plan.row_context.provided -ne [bool]$case.expected_row_provided) {
        Add-Failure -Failures $caseFailures -Message ("row_context.provided expected {0}, got {1}" -f $case.expected_row_provided, $result.payload.plan.row_context.provided)
      }
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
    Write-Host "Xinjian table-column read planning tests passed."
  } else {
    Write-Host "Xinjian table-column read planning tests failed:"
    foreach ($failure in $failures) { Write-Host ("- {0}" -f $failure) }
  }
}

if (!$payload.ok) { exit 1 }
