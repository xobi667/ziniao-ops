[CmdletBinding(PositionalBinding = $false)]
param(
  [switch]$Full,
  [switch]$Refresh,
  [switch]$Json
)

$ErrorActionPreference = "Stop"

function ConvertFrom-JsonText($Lines) {
  $text = (($Lines | Out-String).Trim())
  if (!$text) { return $null }
  try { return $text | ConvertFrom-Json } catch { return $null }
}

$runtimeArgs = @(
  "-NoProfile",
  "-ExecutionPolicy", "Bypass",
  "-File", (Join-Path $PSScriptRoot "get-runtime-status.ps1"),
  "-Json"
)
if ($Refresh) { $runtimeArgs += "-Refresh" }
if ($Full) { $runtimeArgs += "-Full" }
$runtimeRaw = @(& powershell @runtimeArgs 2>&1)
$runtime = ConvertFrom-JsonText $runtimeRaw
if (!$runtime) {
  $runtime = [pscustomobject]@{
    ok = $false
    error = "runtime_status_parse_failed"
    raw_output = ($runtimeRaw | Out-String).Trim()
  }
}

$actionsRaw = @(& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "list-xinjian-page-actions.ps1") -NoAutoOpenLogin -SafeOnly -Limit 8 -Json 2>&1)
$actions = ConvertFrom-JsonText $actionsRaw
if (!$actions) {
  $actions = [pscustomobject]@{
    ok = $false
    error = "page_actions_parse_failed"
    raw_output = ($actionsRaw | Out-String).Trim()
  }
}

$payload = [ordered]@{
  ok = [bool]($runtime -and $runtime.ok -ne $false)
  command = "xj-status"
  runtime_state = $runtime.runtime_state
  summary = $runtime.summary
  current_xinjian = [ordered]@{
    ok = [bool]($actions -and $actions.ok)
    url = if ($actions.PSObject.Properties.Match("current_url").Count -gt 0) { $actions.current_url } else { $null }
    title = if ($actions.PSObject.Properties.Match("current_title").Count -gt 0) { $actions.current_title } else { $null }
    page_kind = if ($actions.PSObject.Properties.Match("page_kind").Count -gt 0) { $actions.page_kind } else { $null }
    resolved_port = if ($actions.PSObject.Properties.Match("resolved_port").Count -gt 0) { $actions.resolved_port } else { $null }
    actions_count = if ($actions.PSObject.Properties.Match("actions").Count -gt 0) { @($actions.actions).Count } else { 0 }
    next_action = if ($actions.PSObject.Properties.Match("next_action").Count -gt 0) { $actions.next_action } else { $null }
  }
  next_actions = @($runtime.next_actions)
  runtime = $runtime
  page_actions = $actions
}

if ($Json) {
  $payload | ConvertTo-Json -Depth 14
} else {
  Write-Host ("XJ_STATUS: {0}" -f $payload.runtime_state)
  Write-Host ("xinjian: {0}" -f $payload.current_xinjian.url)
  Write-Host ("title: {0}" -f $payload.current_xinjian.title)
  Write-Host ("port: {0}" -f $payload.current_xinjian.resolved_port)
  Write-Host ("actions: {0}" -f $payload.current_xinjian.actions_count)
  foreach ($action in @($payload.next_actions)) {
    Write-Host ("next: {0}" -f $action)
  }
  if ($payload.current_xinjian.next_action) {
    Write-Host ("xinjian_next: {0}" -f $payload.current_xinjian.next_action)
  }
}
