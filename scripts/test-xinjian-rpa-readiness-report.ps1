[CmdletBinding(PositionalBinding = $false)]
param(
  [switch]$Json
)

$ErrorActionPreference = "Stop"
$reportScript = Join-Path $PSScriptRoot "report-xinjian-rpa-readiness.ps1"

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

$tmpJson = [System.IO.Path]::ChangeExtension([System.IO.Path]::GetTempFileName(), ".json")
$tmpMd = [System.IO.Path]::ChangeExtension([System.IO.Path]::GetTempFileName(), ".md")
$failures = New-Object System.Collections.Generic.List[object]
$payload = $null

try {
  $raw = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $reportScript -OutputJsonPath $tmpJson -OutputMarkdownPath $tmpMd -Json 2>&1)
  $exitCode = $LASTEXITCODE
  try {
    $payload = ($raw | Out-String | ConvertFrom-Json)
  } catch {
    Add-Failure -Failures $failures -Message ("readiness output was not JSON: {0}" -f ($raw | Out-String).Trim())
  }

  if ($payload) {
    if ($exitCode -ne 0) {
      Add-Failure -Failures $failures -Message ("readiness script exited with {0}" -f $exitCode)
    }
    if (!$payload.ok) {
      Add-Failure -Failures $failures -Message "readiness payload ok=false"
    }
    Test-Equal -Failures $failures -Label "execution_guard_plans.write_confirmation_follow_up" -Actual $payload.execution_guard_plans.write_confirmation_follow_up -Expected $payload.totals.confirmation_required_write
    Test-Equal -Failures $failures -Label "execution_guard_plans.export_download_follow_up" -Actual $payload.execution_guard_plans.export_download_follow_up -Expected $payload.totals.confirmation_required_export
    Test-Equal -Failures $failures -Label "execution_guard_plans.row_context_required_follow_up" -Actual $payload.execution_guard_plans.row_context_required_follow_up -Expected $payload.totals.row_context_required
    Test-Equal -Failures $failures -Label "execution_guard_plans.table_column_read_with_cdp" -Actual $payload.execution_guard_plans.table_column_read_with_cdp -Expected $payload.totals.table_column_readable_with_cdp

    $remaining = @($payload.remaining_boundaries)
    $nonGap = @($payload.non_gap_boundaries)
    $writeBoundary = $remaining | Where-Object { $_.kind -eq "confirmation_required_write" } | Select-Object -First 1
    $exportBoundary = $remaining | Where-Object { $_.kind -eq "confirmation_required_export" } | Select-Object -First 1
    $rowBoundary = $remaining | Where-Object { $_.kind -eq "row_context_required" } | Select-Object -First 1
    Test-Equal -Failures $failures -Label "write handled_by" -Actual $writeBoundary.handled_by -Expected "post_execute.write_confirmation_follow_up"
    Test-Equal -Failures $failures -Label "export handled_by" -Actual $exportBoundary.handled_by -Expected "post_execute.export_download_follow_up"
    Test-Equal -Failures $failures -Label "row handled_by" -Actual $rowBoundary.handled_by -Expected "row_context_follow_up.row_context_required_follow_up"

    foreach ($kind in @("write_confirmation_follow_up_plans", "export_download_follow_up_plans", "row_context_follow_up_plans", "read_only_table_memory")) {
      if (!(@($nonGap | Where-Object { $_.kind -eq $kind }).Count -gt 0)) {
        Add-Failure -Failures $failures -Message ("non_gap_boundaries missing {0}" -f $kind)
      }
    }

    $mdText = if (Test-Path -LiteralPath $tmpMd) { Get-Content -LiteralPath $tmpMd -Raw } else { "" }
    if ($mdText -notmatch "Structured follow-up plans") {
      Add-Failure -Failures $failures -Message "markdown missing structured follow-up summary"
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
    Write-Host "Xinjian RPA readiness report tests passed."
  } else {
    Write-Host "Xinjian RPA readiness report tests failed:"
    foreach ($failure in $failures) { Write-Host ("- {0}" -f $failure) }
  }
}

if (!$result.ok) { exit 1 }
