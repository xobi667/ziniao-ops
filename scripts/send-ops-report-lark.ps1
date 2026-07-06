param(
  [Parameter(Mandatory = $true)]
  [string]$ReportPath,
  [string]$ReceiveId = "",
  [ValidateSet("chat_id", "open_id", "user_id", "email")]
  [string]$ReceiveIdType = "chat_id",
  [switch]$AllowSend,
  [switch]$Json
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
. (Join-Path $PSScriptRoot "sensitive-text.ps1")

function Write-Result($Object, [int]$Code = 0) {
  if ($Json) {
    $Object | ConvertTo-Json -Depth 8
  } else {
    if ($Object.message) { Write-Host $Object.message }
    if ($Object.error) { Write-Host ("error: {0}" -f $Object.error) }
    if ($Object.command) { Write-Host ("command: {0}" -f $Object.command) }
  }
  exit $Code
}

$fullReportPath = if ([System.IO.Path]::IsPathRooted($ReportPath)) { $ReportPath } else { Join-Path $root $ReportPath }
if (!(Test-Path -LiteralPath $fullReportPath -PathType Leaf)) {
  Write-Result ([ordered]@{ ok = $false; error = "report_not_found"; message = "Report file not found."; path = $fullReportPath }) 2
}

$text = Get-Content -LiteralPath $fullReportPath -Raw -Encoding UTF8
if (Test-ZiniaoOpsSecretText $text) {
  Write-Result ([ordered]@{
    ok = $false
    error = "secret_like_report_refused"
    message = "Refusing to send a report that appears to contain secrets or login data."
    path = $fullReportPath
  }) 4
}

$lark = Get-Command "lark-cli" -ErrorAction SilentlyContinue
if (!$lark) {
  Write-Result ([ordered]@{
    ok = $false
    error = "lark_cli_missing"
    message = "lark-cli was not found. Use the available Feishu/Lark IM tool, or install/auth lark-cli on this computer."
    path = $fullReportPath
  }) 3
}

if (!$ReceiveId) {
  Write-Result ([ordered]@{
    ok = $false
    error = "receive_id_required"
    message = "ReceiveId is required before sending to Feishu/Lark."
    path = $fullReportPath
  }) 2
}

$receivePatterns = @{
  chat_id = '^oc_[A-Za-z0-9_-]+$'
  open_id = '^ou_[A-Za-z0-9_-]+$'
  user_id = '^ou_[A-Za-z0-9_-]+$'
  email = '^[^@\s]+@[^@\s]+\.[^@\s]+$'
}
if ($ReceiveId -notmatch $receivePatterns[$ReceiveIdType]) {
  Write-Result ([ordered]@{
    ok = $false
    error = "invalid_receive_id"
    message = "ReceiveId format does not match ReceiveIdType. For direct user messages, use a Feishu open_id that starts with ou_."
    receive_id_type = $ReceiveIdType
    path = $fullReportPath
  }) 2
}
if ($ReceiveIdType -eq "email") {
  Write-Result ([ordered]@{
    ok = $false
    error = "email_receive_id_not_supported"
    message = "Resolve the email to a Feishu open_id first, then rerun with -ReceiveIdType open_id."
    path = $fullReportPath
  }) 2
}

$receiveFlag = if ($ReceiveIdType -eq "chat_id") { "--chat-id" } else { "--user-id" }

$argv = @(
  "im",
  "+messages-send",
  "--as", "user",
  $receiveFlag, $ReceiveId,
  "--markdown", $text,
  "--idempotency-key", ("ziniao-ops-report-" + ([guid]::NewGuid().ToString("N"))),
  "--json"
)
$displayArgv = @(
  "im",
  "+messages-send",
  "--as", "user",
  $receiveFlag, $ReceiveId,
  "--markdown", "<report_text>",
  "--idempotency-key", "<generated>",
  "--json"
)
$commandDisplay = "lark-cli " + (($displayArgv | ForEach-Object {
  if ($_ -match '\s|"') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ }
}) -join " ")

if (!$AllowSend) {
  Write-Result ([ordered]@{
    ok = $false
    error = "send_confirmation_required"
    message = "Dry run only. Rerun with -AllowSend after confirming the target chat/user."
    command = $commandDisplay
    path = $fullReportPath
  }) 4
}

$output = @(& lark-cli @argv 2>&1)
$code = $LASTEXITCODE
Write-Result ([ordered]@{
  ok = ($code -eq 0)
  exit_code = $code
  command = $commandDisplay
  output = @($output | ForEach-Object { $_.ToString() })
  path = $fullReportPath
}) $code
