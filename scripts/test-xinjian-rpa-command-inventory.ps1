[CmdletBinding(PositionalBinding = $false)]
param(
  [switch]$Json
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$generator = Join-Path $PSScriptRoot "generate-xinjian-rpa-command-inventory.ps1"

function Add-Failure {
  param(
    [System.Collections.Generic.List[object]]$Failures,
    [string]$Message
  )
  [void]$Failures.Add($Message)
}

function Test-Equal {
  param(
    [System.Collections.Generic.List[object]]$Failures,
    [string]$Label,
    [object]$Actual,
    [object]$Expected
  )
  if ([string]$Actual -ne [string]$Expected) {
    Add-Failure -Failures $Failures -Message ("{0} expected '{1}', got '{2}'" -f $Label, $Expected, $Actual)
  }
}

function U([int[]]$Codepoints) {
  return -join ($Codepoints | ForEach-Object { [char]$_ })
}

$tmpJson = [System.IO.Path]::ChangeExtension([System.IO.Path]::GetTempFileName(), ".json")
$tmpMd = [System.IO.Path]::ChangeExtension([System.IO.Path]::GetTempFileName(), ".md")
$failures = [System.Collections.Generic.List[object]]::new()
$payload = $null

try {
  $raw = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $generator -OutputJsonPath $tmpJson -OutputMarkdownPath $tmpMd -Json 2>&1)
  $exitCode = $LASTEXITCODE
  try {
    $payload = ($raw | Out-String | ConvertFrom-Json)
  } catch {
    Add-Failure -Failures $failures -Message ("inventory output was not JSON: {0}" -f ($raw | Out-String).Trim())
  }

  if ($payload) {
    if ($exitCode -ne 0) {
      Add-Failure -Failures $failures -Message ("inventory generator exited with {0}" -f $exitCode)
    }
    if (!$payload.ok) {
      Add-Failure -Failures $failures -Message "inventory payload ok=false"
    }
    Test-Equal -Failures $failures -Label "inventory_actions" -Actual $payload.totals.inventory_actions -Expected $payload.totals.catalog_actions
    Test-Equal -Failures $failures -Label "exact_query_commands" -Actual $payload.totals.exact_query_commands -Expected $payload.totals.catalog_actions
    Test-Equal -Failures $failures -Label "dry_run_commands" -Actual $payload.totals.dry_run_commands -Expected $payload.totals.catalog_actions
    Test-Equal -Failures $failures -Label "write_confirmation_commands" -Actual $payload.totals.write_confirmation_commands -Expected 83
    Test-Equal -Failures $failures -Label "export_confirmation_commands" -Actual $payload.totals.export_confirmation_commands -Expected 9
    Test-Equal -Failures $failures -Label "row_context_command_templates" -Actual $payload.totals.row_context_command_templates -Expected 12
    Test-Equal -Failures $failures -Label "table_read_commands" -Actual $payload.totals.table_read_commands -Expected 460

    $switchCurrency = U @(0x5207, 0x6362, 0x5E01, 0x79CD)
    $exactId = "auto.ad.group.detail.button.$switchCurrency"
    $exactRecord = @($payload.commands | Where-Object { [string]$_.action_id -eq $exactId } | Select-Object -First 1)
    if ($exactRecord.Count -eq 0) {
      Add-Failure -Failures $failures -Message "missing exact switch-currency action record"
    } else {
      Test-Equal -Failures $failures -Label "exact dry_run action_id" -Actual $exactRecord[0].commands.dry_run.flags.action_id -Expected $exactId
      Test-Equal -Failures $failures -Label "exact execute_safe action_id" -Actual $exactRecord[0].commands.execute_safe.flags.action_id -Expected $exactId
      Test-Equal -Failures $failures -Label "exact execute_safe execute" -Actual $exactRecord[0].commands.execute_safe.flags.execute -Expected $true
    }

    $unsafeWrite = @($payload.commands | Where-Object { $_.safety_mode -eq "confirmation_required_write" -and $_.commands.execute_safe } | Select-Object -First 1)
    if ($unsafeWrite.Count -gt 0) {
      Add-Failure -Failures $failures -Message ("write action has execute_safe command: {0}" -f $unsafeWrite[0].action_id)
    }
    $writeWithoutAllow = @($payload.commands | Where-Object { $_.commands.confirmed_write -and !$_.commands.confirmed_write.command.flags.allow_write } | Select-Object -First 1)
    if ($writeWithoutAllow.Count -gt 0) {
      Add-Failure -Failures $failures -Message ("write action missing allow_write: {0}" -f $writeWithoutAllow[0].action_id)
    }
    $exportWithoutAllow = @($payload.commands | Where-Object { $_.commands.confirmed_export -and !$_.commands.confirmed_export.command.flags.allow_export } | Select-Object -First 1)
    if ($exportWithoutAllow.Count -gt 0) {
      Add-Failure -Failures $failures -Message ("export action missing allow_export: {0}" -f $exportWithoutAllow[0].action_id)
    }
    $rowWithDefaultFirstRow = @($payload.commands | Where-Object { $_.commands.row_context -and [string]$_.commands.row_context.row_index_command.flags.row_index -eq "1" } | Select-Object -First 1)
    if ($rowWithDefaultFirstRow.Count -gt 0) {
      Add-Failure -Failures $failures -Message ("row action defaults to first row: {0}" -f $rowWithDefaultFirstRow[0].action_id)
    }
    $tableWithoutCdp = @($payload.commands | Where-Object { $_.commands.read_table_column -and !$_.commands.read_table_column.requires_debuggable_cdp } | Select-Object -First 1)
    if ($tableWithoutCdp.Count -gt 0) {
      Add-Failure -Failures $failures -Message ("table read command missing CDP requirement: {0}" -f $tableWithoutCdp[0].action_id)
    }

    $mdText = if (Test-Path -LiteralPath $tmpMd) { Get-Content -LiteralPath $tmpMd -Raw } else { "" }
    if ($mdText -notmatch "Xinjian RPA Command Inventory") {
      Add-Failure -Failures $failures -Message "markdown missing inventory title"
    }
  }
} finally {
  Remove-Item -LiteralPath $tmpJson -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $tmpMd -ErrorAction SilentlyContinue
}

$result = [ordered]@{
  ok = ($failures.Count -eq 0)
  failures = @($failures.ToArray())
}

if ($Json) {
  $result | ConvertTo-Json -Depth 8
} else {
  if ($result.ok) {
    Write-Host "Xinjian RPA command inventory tests passed."
  } else {
    Write-Host "Xinjian RPA command inventory tests failed:"
    foreach ($failure in $failures) { Write-Host ("- {0}" -f $failure) }
  }
}

if (!$result.ok) { exit 1 }
