[CmdletBinding(PositionalBinding = $false)]
param(
  [switch]$Json
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path

function Add-Failure {
  param(
    [System.Collections.Generic.List[object]]$Failures,
    [string]$Message
  )
  [void]$Failures.Add($Message)
}

function ConvertFrom-JsonText($Lines) {
  $text = (($Lines | Out-String).Trim())
  if (!$text) { return $null }
  try { return $text | ConvertFrom-Json } catch { return $null }
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

$failures = [System.Collections.Generic.List[object]]::new()
$fakeBridge = Join-Path ([System.IO.Path]::GetTempPath()) ("fake-open-xinjian-login-{0}.ps1" -f ([guid]::NewGuid().ToString("N")))
$fakeBridgeText = @'
param(
  [int]$Port = 9339,
  [string]$Url = "",
  [switch]$Json
)

$payload = [ordered]@{
  ok = $true
  browser = "fake-browser"
  port = $Port
  url = $Url
  user_data_dir = ""
  window = "minimized"
  skipped_debuggable_open = $false
  force_debuggable = $false
  reused_existing_page = $false
  opened_new_tab = $true
  matched_page_url = "https://erp.xinjianerp.com/login"
  matched_page_title = "Xinjian ERP Login"
  matched_page_id = "fake-page"
  matched_page_score = 10
  matched_page_kind = "login_page"
  next_action = "manual_login_required_in_debuggable_xinjian_browser"
  fetch_command = ""
}

if ($Json) {
  $payload | ConvertTo-Json -Depth 6
} else {
  Write-Host $payload.next_action
}
'@

try {
  Set-Content -LiteralPath $fakeBridge -Value $fakeBridgeText -Encoding UTF8

  $listScript = Join-Path $PSScriptRoot "list-xinjian-page-actions.ps1"
  $listRaw = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $listScript -NoAutoDetectUrl -LoginBridgeScriptPath $fakeBridge -Json 2>&1)
  $listExit = $LASTEXITCODE
  $listResult = ConvertFrom-JsonText $listRaw
  if (!$listResult) {
    Add-Failure -Failures $failures -Message ("list output was not JSON: {0}" -f ($listRaw | Out-String).Trim())
  } else {
    Test-Equal -Failures $failures -Label "list exit" -Actual $listExit -Expected 1
    Test-Equal -Failures $failures -Label "list mode" -Actual $listResult.mode -Expected "non_business_xinjian_page"
    Test-Equal -Failures $failures -Label "list next_action" -Actual $listResult.next_action -Expected "manual_login_required_in_debuggable_xinjian_browser"
    Test-Equal -Failures $failures -Label "list bridge kind" -Actual $listResult.login_bridge.result.matched_page_kind -Expected "login_page"
  }

  $invokeScript = Join-Path $PSScriptRoot "invoke-xinjian-ui-action.ps1"
  $invokeRaw = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $invokeScript -Intent "open download center" -NoAutoDetectUrl -LoginBridgeScriptPath $fakeBridge -Json 2>&1)
  $invokeExit = $LASTEXITCODE
  $invokeResult = ConvertFrom-JsonText $invokeRaw
  if (!$invokeResult) {
    Add-Failure -Failures $failures -Message ("invoke output was not JSON: {0}" -f ($invokeRaw | Out-String).Trim())
  } else {
    Test-Equal -Failures $failures -Label "invoke exit" -Actual $invokeExit -Expected 1
    Test-Equal -Failures $failures -Label "invoke mode" -Actual $invokeResult.mode -Expected "non_business_xinjian_page"
    Test-Equal -Failures $failures -Label "invoke next_action" -Actual $invokeResult.next_action -Expected "manual_login_required_in_debuggable_xinjian_browser"
    Test-Equal -Failures $failures -Label "invoke bridge kind" -Actual $invokeResult.login_bridge.result.matched_page_kind -Expected "login_page"
  }
} finally {
  Remove-Item -LiteralPath $fakeBridge -ErrorAction SilentlyContinue
}

$result = [ordered]@{
  ok = ($failures.Count -eq 0)
  root = $root
  failures = @($failures.ToArray())
}

if ($Json) {
  $result | ConvertTo-Json -Depth 8
} else {
  if ($result.ok) {
    Write-Host "Xinjian auto-open login bridge tests passed."
  } else {
    Write-Host "Xinjian auto-open login bridge tests failed:"
    foreach ($failure in $failures) { Write-Host ("- {0}" -f $failure) }
  }
}

if (!$result.ok) { exit 1 }
