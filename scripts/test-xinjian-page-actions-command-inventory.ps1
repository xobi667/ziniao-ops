[CmdletBinding(PositionalBinding = $false)]
param(
  [switch]$Json
)

$ErrorActionPreference = "Stop"
$listScript = Join-Path $PSScriptRoot "list-xinjian-page-actions.ps1"
$testUrl = "https://erp.xinjianerp.com/ad/group-detail"

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

function Test-True {
  param(
    [System.Collections.Generic.List[object]]$Failures,
    [string]$Label,
    [object]$Value
  )
  if (!$Value) {
    Add-Failure -Failures $Failures -Message ("{0} expected true" -f $Label)
  }
}

function U([int[]]$Codepoints) {
  return -join ($Codepoints | ForEach-Object { [char]$_ })
}

function Find-ActionById {
  param(
    [object[]]$Actions,
    [string]$ActionId
  )
  return @($Actions | Where-Object { [string]$_.id -eq $ActionId } | Select-Object -First 1)
}

function Assert-BaseCommands {
  param(
    [System.Collections.Generic.List[object]]$Failures,
    [object]$Action,
    [string]$ActionId
  )
  Test-True -Failures $Failures -Label "$ActionId exact_query" -Value $Action.rpa_commands.exact_query
  Test-True -Failures $Failures -Label "$ActionId dry_run" -Value $Action.rpa_commands.dry_run
  Test-Equal -Failures $Failures -Label "$ActionId exact_query action_id" -Actual $Action.rpa_commands.exact_query.flags.action_id -Expected $ActionId
  Test-Equal -Failures $Failures -Label "$ActionId dry_run action_id" -Actual $Action.rpa_commands.dry_run.flags.action_id -Expected $ActionId
}

$failures = [System.Collections.Generic.List[object]]::new()
$payload = $null

try {
  $raw = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $listScript -Url $testUrl -NoAutoDetectUrl -Json 2>&1)
  $exitCode = $LASTEXITCODE
  try {
    $payload = ($raw | Out-String | ConvertFrom-Json)
  } catch {
    Add-Failure -Failures $failures -Message ("page action list output was not JSON: {0}" -f ($raw | Out-String).Trim())
  }

  if ($payload) {
    if ($exitCode -ne 0) {
      Add-Failure -Failures $failures -Message ("page action list exited with {0}" -f $exitCode)
    }
    if (!$payload.ok) {
      Add-Failure -Failures $failures -Message "page action list payload ok=false"
    }
    Test-Equal -Failures $failures -Label "page.route" -Actual $payload.page.route -Expected "/ad/group-detail"
    Test-True -Failures $failures -Label "command inventory loaded" -Value $payload.command_inventory.loaded
    Test-Equal -Failures $failures -Label "command_records" -Actual $payload.counts.command_records -Expected $payload.counts.total
    Test-Equal -Failures $failures -Label "listed_command_records" -Actual $payload.counts.listed_command_records -Expected $payload.counts.listed
    Test-Equal -Failures $failures -Label "next_action" -Actual $payload.next_action -Expected "use_listed_rpa_commands_or_invoke_xinjian_ui_action_with_action_id"

    $actions = @($payload.actions)

    $safeId = "ad.group_detail.switch_currency"
    $safeAction = Find-ActionById -Actions $actions -ActionId $safeId
    if ($safeAction.Count -eq 0) {
      Add-Failure -Failures $failures -Message "missing safe switch-currency action"
    } else {
      $safe = $safeAction[0]
      Test-Equal -Failures $failures -Label "$safeId mode" -Actual $safe.rpa_command_mode -Expected "execute_safe"
      Assert-BaseCommands -Failures $failures -Action $safe -ActionId $safeId
      Test-True -Failures $failures -Label "$safeId execute_safe" -Value $safe.rpa_commands.execute_safe
      Test-Equal -Failures $failures -Label "$safeId execute flag" -Actual $safe.rpa_commands.execute_safe.flags.execute -Expected $true
      Test-Equal -Failures $failures -Label "$safeId allow_write" -Actual $safe.rpa_commands.execute_safe.flags.allow_write -Expected $false
    }

    $writeId = "ad.group_detail.modify"
    $writeAction = Find-ActionById -Actions $actions -ActionId $writeId
    if ($writeAction.Count -eq 0) {
      Add-Failure -Failures $failures -Message "missing write modify action"
    } else {
      $write = $writeAction[0]
      Test-Equal -Failures $failures -Label "$writeId mode" -Actual $write.rpa_command_mode -Expected "confirmed_write"
      Assert-BaseCommands -Failures $failures -Action $write -ActionId $writeId
      if ($write.rpa_commands.execute_safe) {
        Add-Failure -Failures $failures -Message "$writeId unexpectedly has execute_safe command"
      }
      Test-True -Failures $failures -Label "$writeId confirmed_write" -Value $write.rpa_commands.confirmed_write
      Test-Equal -Failures $failures -Label "$writeId allow_write" -Actual $write.rpa_commands.confirmed_write.command.flags.allow_write -Expected $true
      Test-Equal -Failures $failures -Label "$writeId execute flag" -Actual $write.rpa_commands.confirmed_write.command.flags.execute -Expected $true
    }

    $keyword = U @(0x5173, 0x952E, 0x8BCD)
    $tableId = "ad.group.detail.table.column.$keyword"
    $tableAction = Find-ActionById -Actions $actions -ActionId $tableId
    if ($tableAction.Count -eq 0) {
      Add-Failure -Failures $failures -Message "missing table keyword action"
    } else {
      $table = $tableAction[0]
      Test-Equal -Failures $failures -Label "$tableId mode" -Actual $table.rpa_command_mode -Expected "read_table_column"
      Assert-BaseCommands -Failures $failures -Action $table -ActionId $tableId
      if ($table.rpa_commands.execute_safe) {
        Add-Failure -Failures $failures -Message "$tableId unexpectedly has click execute_safe command"
      }
      Test-True -Failures $failures -Label "$tableId read_table_column" -Value $table.rpa_commands.read_table_column
      Test-Equal -Failures $failures -Label "$tableId requires_debuggable_cdp" -Actual $table.rpa_commands.read_table_column.requires_debuggable_cdp -Expected $true
      Test-Equal -Failures $failures -Label "$tableId no_click" -Actual $table.rpa_commands.read_table_column.no_click -Expected $true
      Test-Equal -Failures $failures -Label "$tableId read command execute" -Actual $table.rpa_commands.read_table_column.command.flags.execute -Expected $true
    }
  }
} catch {
  Add-Failure -Failures $failures -Message $_.Exception.Message
}

$result = [ordered]@{
  ok = ($failures.Count -eq 0)
  failures = @($failures.ToArray())
}

if ($Json) {
  $result | ConvertTo-Json -Depth 8
} else {
  if ($result.ok) {
    Write-Host "Xinjian page action command inventory tests passed."
  } else {
    Write-Host "Xinjian page action command inventory tests failed:"
    foreach ($failure in $failures) { Write-Host ("- {0}" -f $failure) }
  }
}

if (!$result.ok) { exit 1 }
