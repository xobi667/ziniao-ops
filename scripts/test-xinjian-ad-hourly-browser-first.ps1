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
$successBridge = Join-Path ([System.IO.Path]::GetTempPath()) ("fake-xinjian-browser-success-{0}.ps1" -f ([guid]::NewGuid().ToString("N")))
$apiOnlyBridge = Join-Path ([System.IO.Path]::GetTempPath()) ("fake-xinjian-browser-api-only-{0}.ps1" -f ([guid]::NewGuid().ToString("N")))
$loginBridge = Join-Path ([System.IO.Path]::GetTempPath()) ("fake-xinjian-browser-login-{0}.ps1" -f ([guid]::NewGuid().ToString("N")))

$successBridgeText = @'
param(
  [string[]]$StoreName = @(),
  [int]$Days = 7,
  [string]$StartDate = "",
  [string]$EndDate = "",
  [string]$OutputPath = "",
  [string]$ExcelOutputPath = "",
  [string]$Url = "",
  [switch]$Json
)

$payload = [ordered]@{
  ok = $true
  method = "fake_browser_page"
  real_data_verified = $true
  ui_interaction_verified = $true
  ui_interaction = [ordered]@{
    required = $true
    verified = $true
    clicked_count = 2
    actions = @(
      [ordered]@{ action = "click"; label = "select_last_7_days"; clicked = $true },
      [ordered]@{ action = "click"; label = "run_visible_query"; clicked = $true }
    )
  }
  page_url = $Url
  data_source = [ordered]@{
    type = "browser_cdp_endpoint_response"
    verified = $true
    evidence = [ordered]@{
      page_url = $Url
      record_count = 3
      files_used = @("fake-response.json")
      source_types = @("xinjian_endpoint_json")
      ui_interaction_verified = $true
    }
  }
  analysis = [ordered]@{
    ok = $true
    record_count = 3
  }
  output = $OutputPath
  excel_output = $ExcelOutputPath
  next_action = $null
}

if ($Json) { $payload | ConvertTo-Json -Depth 8 } else { Write-Host "OK" }
'@

$apiOnlyBridgeText = @'
param(
  [string[]]$StoreName = @(),
  [int]$Days = 7,
  [string]$StartDate = "",
  [string]$EndDate = "",
  [string]$OutputPath = "",
  [string]$ExcelOutputPath = "",
  [string]$Url = "",
  [switch]$Json
)

$payload = [ordered]@{
  ok = $true
  method = "fake_browser_page"
  real_data_verified = $true
  ui_interaction_verified = $false
  page_url = $Url
  data_source = [ordered]@{
    type = "browser_cdp_endpoint_response"
    verified = $false
    evidence = [ordered]@{
      page_url = $Url
      record_count = 3
      files_used = @("fake-response.json")
      source_types = @("xinjian_endpoint_json")
      ui_interaction_verified = $false
    }
  }
  output = $OutputPath
  excel_output = $ExcelOutputPath
  next_action = "verified_ui_interaction_required"
}

if ($Json) { $payload | ConvertTo-Json -Depth 8 } else { Write-Host "API_ONLY" }
'@

$loginBridgeText = @'
param(
  [string[]]$StoreName = @(),
  [int]$Days = 7,
  [string]$OutputPath = "",
  [string]$ExcelOutputPath = "",
  [string]$Url = "",
  [switch]$Json
)

$payload = [ordered]@{
  ok = $false
  method = "fake_browser_page"
  real_data_verified = $false
  login_state = "not_logged_in"
  page_url = $Url
  next_action = "manual_login_required"
}

if ($Json) { $payload | ConvertTo-Json -Depth 8 } else { Write-Host "LOGIN_REQUIRED" }
'@

try {
  Set-Content -LiteralPath $successBridge -Value $successBridgeText -Encoding UTF8
  Set-Content -LiteralPath $apiOnlyBridge -Value $apiOnlyBridgeText -Encoding UTF8
  Set-Content -LiteralPath $loginBridge -Value $loginBridgeText -Encoding UTF8

  $script = Join-Path $PSScriptRoot "xinjian-erp-ad-hourly.ps1"
  $successRaw = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $script -StoreName "DEMO" -BrowserBridgeScriptPath $successBridge -Json 2>&1)
  $successExit = $LASTEXITCODE
  $success = ConvertFrom-JsonText $successRaw
  if (!$success) {
    Add-Failure -Failures $failures -Message ("success output was not JSON: {0}" -f ($successRaw | Out-String).Trim())
  } else {
    Test-Equal -Failures $failures -Label "success exit" -Actual $successExit -Expected 0
    Test-Equal -Failures $failures -Label "success mode" -Actual $success.mode -Expected "browser_page_fetch"
    Test-Equal -Failures $failures -Label "success verified" -Actual $success.real_data_verified -Expected $true
    Test-Equal -Failures $failures -Label "success ui verified" -Actual $success.ui_interaction_verified -Expected $true
    Test-Equal -Failures $failures -Label "success source" -Actual $success.data_source.type -Expected "browser_cdp_endpoint_response"
  }

  $apiOnlyRaw = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $script -StoreName "DEMO" -BrowserBridgeScriptPath $apiOnlyBridge -Json 2>&1)
  $apiOnlyExit = $LASTEXITCODE
  $apiOnly = ConvertFrom-JsonText $apiOnlyRaw
  if (!$apiOnly) {
    Add-Failure -Failures $failures -Message ("api-only output was not JSON: {0}" -f ($apiOnlyRaw | Out-String).Trim())
  } else {
    Test-Equal -Failures $failures -Label "api-only exit" -Actual $apiOnlyExit -Expected 0
    Test-Equal -Failures $failures -Label "api-only mode" -Actual $apiOnly.mode -Expected "browser_page_required"
    Test-Equal -Failures $failures -Label "api-only verified" -Actual $apiOnly.real_data_verified -Expected $false
    Test-Equal -Failures $failures -Label "api-only local fallback skipped" -Actual $apiOnly.local_fallback_skipped -Expected $true
  }

  $loginRaw = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $script -StoreName "DEMO" -BrowserBridgeScriptPath $loginBridge -Json 2>&1)
  $loginExit = $LASTEXITCODE
  $login = ConvertFrom-JsonText $loginRaw
  if (!$login) {
    Add-Failure -Failures $failures -Message ("login output was not JSON: {0}" -f ($loginRaw | Out-String).Trim())
  } else {
    Test-Equal -Failures $failures -Label "login exit" -Actual $loginExit -Expected 0
    Test-Equal -Failures $failures -Label "login mode" -Actual $login.mode -Expected "browser_page_required"
    Test-Equal -Failures $failures -Label "login verified" -Actual $login.real_data_verified -Expected $false
    Test-Equal -Failures $failures -Label "login next_action" -Actual $login.next_action -Expected "manual_login_required"
    Test-Equal -Failures $failures -Label "local fallback skipped" -Actual $login.local_fallback_skipped -Expected $true
  }
} finally {
  Remove-Item -LiteralPath $successBridge -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $apiOnlyBridge -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $loginBridge -ErrorAction SilentlyContinue
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
    Write-Host "Xinjian ad-hourly browser-first tests passed."
  } else {
    Write-Host "Xinjian ad-hourly browser-first tests failed:"
    foreach ($failure in $failures) { Write-Host ("- {0}" -f $failure) }
  }
}

if (!$result.ok) { exit 1 }
