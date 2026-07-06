param(
  [Parameter(Mandatory = $true)]
  [string]$ReportPath,
  [string]$ReceiveId = "",
  [ValidateSet("chat_id", "open_id", "user_id", "email")]
  [string]$ReceiveIdType = "chat_id",
  [string]$CommandTemplate = "",
  [switch]$AllowSend,
  [switch]$Json
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path

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

$text = Get-Content -LiteralPath $fullReportPath -Raw
$secretPattern = [regex]"(?i)(password|passwd|pwd|secret|token|cookie|session|private[_\s-]?key|verification\s*code)\s*[:=]\s*\S+"
if ($secretPattern.IsMatch($text)) {
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

if (!$CommandTemplate) {
  $CommandTemplate = 'lark-cli im message send --receive-id-type "{receive_id_type}" --receive-id "{receive_id}" --msg-type text --text-file "{report_path}"'
}

$command = $CommandTemplate.Replace("{receive_id_type}", $ReceiveIdType).Replace("{receive_id}", $ReceiveId).Replace("{report_path}", $fullReportPath)

if (!$AllowSend) {
  Write-Result ([ordered]@{
    ok = $false
    error = "send_confirmation_required"
    message = "Dry run only. Rerun with -AllowSend after confirming the target chat/user and lark-cli command template."
    command = $command
    path = $fullReportPath
  }) 4
}

$output = @(& powershell -NoProfile -ExecutionPolicy Bypass -Command $command 2>&1)
$code = $LASTEXITCODE
Write-Result ([ordered]@{
  ok = ($code -eq 0)
  exit_code = $code
  command = $command
  output = @($output | ForEach-Object { $_.ToString() })
  path = $fullReportPath
}) $code
