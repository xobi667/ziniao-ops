[CmdletBinding(PositionalBinding = $false)]
param(
  [switch]$Json
)

$ErrorActionPreference = "Stop"
$invokeScript = Join-Path $PSScriptRoot "invoke-xinjian-ui-action.ps1"
$testUrl = "https://erp.xinjianerp.com/system/costom-fee"

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

function Invoke-ActionPlan {
  param(
    [string]$Intent,
    [int]$RowIndex = 0,
    [string]$RowText = ""
  )
  $argsList = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", $invokeScript,
    "-Intent", $Intent,
    "-Url", $testUrl,
    "-Json"
  )
  if ($RowIndex -gt 0) { $argsList += @("-RowIndex", [string]$RowIndex) }
  if (![string]::IsNullOrWhiteSpace($RowText)) { $argsList += @("-RowText", $RowText) }
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

$textEdit = U @(0x7f16, 0x8f91)
$textFirstRowDigit = (U @(0x7b2c)) + "1" + (U @(0x884c)) + " " + $textEdit
$textFirstRowChinese = (U @(0x7b2c, 0x4e00, 0x884c)) + " " + $textEdit
$textContainsTestRow = $textEdit + " " + (U @(0x5305, 0x542b)) + "TEST" + (U @(0x7684, 0x884c))

$cases = @(
  [pscustomobject]@{
    name = "no_row_context_blocks"
    intent = $textEdit
    expected_required = $true
    expected_provided = $false
    expected_source = $null
    expected_row_index = $null
    expected_row_text = $null
  },
  [pscustomobject]@{
    name = "infer_numeric_row_index"
    intent = $textFirstRowDigit
    expected_required = $true
    expected_provided = $true
    expected_source = "intent_row_index"
    expected_row_index = 1
    expected_row_text = $null
  },
  [pscustomobject]@{
    name = "infer_chinese_row_index"
    intent = $textFirstRowChinese
    expected_required = $true
    expected_provided = $true
    expected_source = "intent_row_index"
    expected_row_index = 1
    expected_row_text = $null
  },
  [pscustomobject]@{
    name = "infer_row_text"
    intent = $textContainsTestRow
    expected_required = $true
    expected_provided = $true
    expected_source = "intent_row_text"
    expected_row_index = $null
    expected_row_text = "[provided]"
  },
  [pscustomobject]@{
    name = "explicit_row_index_overrides_intent"
    intent = $textFirstRowDigit
    row_index = 2
    expected_required = $true
    expected_provided = $true
    expected_source = "argument"
    expected_row_index = 2
    expected_row_text = $null
  }
)

$results = New-Object System.Collections.Generic.List[object]
$failures = New-Object System.Collections.Generic.List[object]

foreach ($case in $cases) {
  $rowIndex = 0
  if ($case.PSObject.Properties.Name -contains "row_index") { $rowIndex = [int]$case.row_index }
  $result = Invoke-ActionPlan -Intent $case.intent -RowIndex $rowIndex
  $caseFailures = New-Object System.Collections.Generic.List[object]

  if (!$result.ok) {
    Add-Failure -Failures $caseFailures -Message ("invoke output was not JSON: {0}" -f $result.raw)
  } else {
    $ctx = $result.payload.plan.row_context
    if ($null -eq $ctx) {
      Add-Failure -Failures $caseFailures -Message "plan.row_context missing"
    } else {
      if ([bool]$ctx.required -ne [bool]$case.expected_required) {
        Add-Failure -Failures $caseFailures -Message ("required expected {0}, got {1}" -f $case.expected_required, $ctx.required)
      }
      if ([bool]$ctx.provided -ne [bool]$case.expected_provided) {
        Add-Failure -Failures $caseFailures -Message ("provided expected {0}, got {1}" -f $case.expected_provided, $ctx.provided)
      }
      if ([string]$ctx.source -ne [string]$case.expected_source) {
        Add-Failure -Failures $caseFailures -Message ("source expected '{0}', got '{1}'" -f $case.expected_source, $ctx.source)
      }
      if ([string]$ctx.row_index -ne [string]$case.expected_row_index) {
        Add-Failure -Failures $caseFailures -Message ("row_index expected '{0}', got '{1}'" -f $case.expected_row_index, $ctx.row_index)
      }
      if ([string]$ctx.row_text -ne [string]$case.expected_row_text) {
        Add-Failure -Failures $caseFailures -Message ("row_text expected '{0}', got '{1}'" -f $case.expected_row_text, $ctx.row_text)
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
    Write-Host "Xinjian row-context inference tests passed."
  } else {
    Write-Host "Xinjian row-context inference tests failed:"
    foreach ($failure in $failures) { Write-Host ("- {0}" -f $failure) }
  }
}

if (!$payload.ok) { exit 1 }
