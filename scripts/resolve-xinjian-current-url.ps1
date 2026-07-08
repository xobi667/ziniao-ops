[CmdletBinding(PositionalBinding = $false)]
param(
  [int[]]$Port = @(),
  [string]$Intent = "",
  [switch]$Json
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path

function ConvertFrom-JsonText($Lines) {
  $text = (($Lines | Out-String).Trim())
  if (!$text) { return $null }
  try { return $text | ConvertFrom-Json } catch {
    $objectStart = $text.IndexOf("{")
    $arrayStart = $text.IndexOf("[")
    $starts = @($objectStart, $arrayStart) | Where-Object { $_ -ge 0 } | Sort-Object
    if ($starts.Count -eq 0) { return $null }
    try { return $text.Substring([int]$starts[0]) | ConvertFrom-Json } catch { return $null }
  }
}

function Test-XinjianUrl([string]$Value) {
  $text = [string]$Value
  return $text -match "^https?://erp\.xinjianerp\.com/" -and $text -notmatch "\s"
}

function Get-RouteKey([string]$InputUrl) {
  if (!$InputUrl) { return "" }
  $value = [string]$InputUrl
  if ($value -match "^[A-Za-z][A-Za-z0-9+.-]*://") {
    try {
      $uri = [uri]$value
      $value = $uri.AbsolutePath
    } catch {
    }
  }
  if (!$value) { return "" }
  if (!$value.StartsWith("/")) { $value = "/" + $value }
  $value = $value -replace "/+", "/"
  if ($value.Length -gt 1) { $value = $value.TrimEnd("/") }
  return $value.ToLowerInvariant()
}

function Get-XinjianPageKind([string]$InputUrl) {
  $routeKey = Get-RouteKey $InputUrl
  if (!$routeKey) { return "unknown" }
  if ($routeKey -match "^/(login|xtlogin|sso|social-login|redirect)(/|$)") { return "login_page" }
  if ($routeKey -match "^/(401|404)(/|$)" -or $routeKey -match "^/index/(noaccess|ad-no-auth)(/|$)") { return "non_business_page" }
  return "business_page"
}

function Get-ForegroundProcessId {
  try {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class ZiniaoOpsCurrentUrlNativeWindow {
  [DllImport("user32.dll")]
  public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")]
  public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
}
"@ -ErrorAction SilentlyContinue | Out-Null
    $processIdValue = [uint32]0
    $handle = [ZiniaoOpsCurrentUrlNativeWindow]::GetForegroundWindow()
    if ($handle -eq [IntPtr]::Zero) { return $null }
    [void][ZiniaoOpsCurrentUrlNativeWindow]::GetWindowThreadProcessId($handle, [ref]$processIdValue)
    if ($processIdValue -gt 0) { return [int]$processIdValue }
  } catch {
  }
  return $null
}

function Invoke-XinjianActionQuery {
  param(
    [string]$QueryIntent,
    [string]$QueryUrl
  )
  $queryScript = Join-Path $PSScriptRoot "query-xinjian-ui-action.ps1"
  if (!(Test-Path -LiteralPath $queryScript)) {
    return [pscustomobject]@{ ok = $false; error = "query_script_missing"; parsed = $null; raw = @(); exit_code = 2 }
  }
  $queryArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $queryScript, "-Intent", $QueryIntent, "-Json")
  if ($QueryUrl) { $queryArgs += @("-Url", $QueryUrl) }
  $raw = @(& powershell @queryArgs 2>&1)
  [pscustomobject]@{
    ok = ($LASTEXITCODE -eq 0)
    raw = $raw
    exit_code = $LASTEXITCODE
    parsed = ConvertFrom-JsonText $raw
  }
}

function Get-PortArgumentList {
  param([int[]]$Ports)
  $items = @($Ports | Where-Object { $_ -gt 0 } | Sort-Object -Unique)
  $args = @()
  foreach ($item in $items) {
    $args += @("-Port", [string]$item)
  }
  return $args
}

function Resolve-XinjianUrlByIntent {
  param(
    [string]$QueryIntent,
    [object[]]$Candidates
  )
  if (!$QueryIntent) { return $null }
  $urls = @($Candidates |
    ForEach-Object { [string]$_.url } |
    Where-Object { Test-XinjianUrl $_ } |
    Sort-Object -Unique)
  if ($urls.Count -lt 2) { return $null }

  $scores = @()
  foreach ($candidateUrl in $urls) {
    $matchingCandidate = @($Candidates | Where-Object { [string]$_.url -eq $candidateUrl } | Select-Object -First 1)
    $probe = Invoke-XinjianActionQuery -QueryIntent $QueryIntent -QueryUrl $candidateUrl
    if (!$probe.parsed -or !$probe.parsed.ok -or @($probe.parsed.matches).Count -eq 0) {
      $scores += [pscustomobject]@{
        url = $candidateUrl
        port = if ($matchingCandidate.Count -gt 0) { $matchingCandidate[0].port } else { $null }
        ok = $false
        score = 0
        rank = 0
        page_name = ""
        action_name = ""
      }
      continue
    }
    $best = @($probe.parsed.matches)[0]
    $scores += [pscustomobject]@{
      url = $candidateUrl
      port = if ($matchingCandidate.Count -gt 0) { $matchingCandidate[0].port } else { $null }
      ok = $true
      score = [int]$best.score
      rank = [int]$best.rank
      page_name = [string]$best.page_name
      action_name = [string]$best.action.name
    }
  }

  $ordered = @($scores | Sort-Object @{ Expression = "score"; Descending = $true }, @{ Expression = "rank"; Descending = $true })
  if ($ordered.Count -eq 0 -or !$ordered[0].ok -or $ordered[0].score -le 0) { return $null }
  if ($ordered.Count -gt 1 -and $ordered[1].ok -and $ordered[1].score -eq $ordered[0].score -and $ordered[1].rank -eq $ordered[0].rank) {
    return $null
  }

  return [pscustomobject]@{
    url = [string]$ordered[0].url
    port = $ordered[0].port
    score = [int]$ordered[0].score
    rank = [int]$ordered[0].rank
    page_name = [string]$ordered[0].page_name
    action_name = [string]$ordered[0].action_name
    candidates = @($ordered)
  }
}

$payload = [ordered]@{
  ok = $false
  url = ""
  source = ""
  confidence = "none"
  reason = ""
  ports = @($Port | Where-Object { $_ -gt 0 } | Sort-Object -Unique)
  resolved_port = $null
  candidate_scope = "all_detected"
  all_candidate_count = 0
  ignored_candidate_count = 0
  business_candidate_count = 0
  ignored_non_business_candidate_count = 0
  candidates = @()
  intent_resolution = $null
}

$detector = Join-Path $PSScriptRoot "detect-ziniao-windows.ps1"
if (!(Test-Path -LiteralPath $detector)) {
  $payload.reason = "detector_missing"
  if ($Json) { $payload | ConvertTo-Json -Depth 12 } else { Write-Host "Xinjian detector missing." }
  exit 2
}

$detectArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $detector)
$detectArgs += Get-PortArgumentList -Ports $Port
$detectArgs += "-Json"
$rawDetected = @(& powershell @detectArgs 2>&1)
$detected = ConvertFrom-JsonText $rawDetected
if (!$detected -or !$detected.ok) {
  $payload.reason = "detector_failed"
  $payload.detector_raw = ($rawDetected | Out-String).Trim()
  if ($Json) { $payload | ConvertTo-Json -Depth 12 } else { Write-Host "Xinjian detector failed." }
  exit 2
}

$foregroundProcessId = Get-ForegroundProcessId
$script:CandidateUrls = @{}
$script:Candidates = @()
function Add-Candidate {
  param(
    [string]$Source,
    [object]$ProcessId,
    [string]$Title,
    [string]$Url,
    [bool]$Reachable = $false,
    [object]$CdpPort = $null
  )
  if (!(Test-XinjianUrl $Url)) { return }
  $key = ([string]$Url).ToLowerInvariant()
  if ($script:CandidateUrls.ContainsKey($key)) {
    $existing = $script:Candidates | Where-Object { ([string]$_.url).ToLowerInvariant() -eq $key } | Select-Object -First 1
    if ($existing -and $foregroundProcessId -and $ProcessId -and [int]$ProcessId -eq $foregroundProcessId) {
      $existing.is_foreground_process = $true
    }
    if ($existing -and $CdpPort -and !$existing.port) {
      $existing.port = [int]$CdpPort
      $existing.reachable = [bool]$Reachable
    }
    return
  }
  $script:CandidateUrls[$key] = $true
  $script:Candidates += [pscustomobject]([ordered]@{
      source = $Source
      process_id = $ProcessId
      port = if ($CdpPort) { [int]$CdpPort } else { $null }
      title = $Title
      url = $Url
      page_kind = Get-XinjianPageKind $Url
      is_foreground_process = ($foregroundProcessId -and $ProcessId -and [int]$ProcessId -eq $foregroundProcessId)
      reachable = [bool]$Reachable
    })
}

$windows = @($detected.windows | Where-Object {
    $_.platform -eq "xinjian_erp" -and $_.page_url -and (Test-XinjianUrl ([string]$_.page_url))
  })
foreach ($window in @($windows | Where-Object { $_.source -in @("cdp", "window_uia", "window_title") })) {
  Add-Candidate -Source ([string]$window.source) -ProcessId $window.process_id -Title ([string]$window.page_title) -Url ([string]$window.page_url) -Reachable ([bool]$window.reachable) -CdpPort $window.port
}

foreach ($probePort in @($Port | Where-Object { $_ -gt 0 } | Sort-Object -Unique)) {
  try {
    $body = (Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:$probePort/json" -TimeoutSec 5).Content
    $parsedPages = $body | ConvertFrom-Json
    $pages = @($parsedPages | ForEach-Object { $_ })
    foreach ($page in @($pages | Where-Object { $_.type -eq "page" -and (Test-XinjianUrl ([string]$_.url)) })) {
      Add-Candidate -Source "cdp_page_url" -ProcessId $null -Title ([string]$page.title) -Url ([string]$page.url) -Reachable $true -CdpPort $probePort
    }
  } catch {
  }
}

$explicitPorts = @($Port | Where-Object { $_ -gt 0 } | Sort-Object -Unique)
$selectionCandidates = @($script:Candidates)
if ($explicitPorts.Count -gt 0) {
  $portCandidates = @($script:Candidates | Where-Object {
      $_.port -and ($explicitPorts -contains [int]$_.port)
    })
  if ($portCandidates.Count -gt 0) {
    $selectionCandidates = $portCandidates
    $payload.candidate_scope = "explicit_port"
    $payload.ignored_candidate_count = [Math]::Max(0, $script:Candidates.Count - $portCandidates.Count)
  } else {
    $payload.candidate_scope = "all_detected_no_explicit_port_match"
  }
}

$payload.all_candidate_count = $script:Candidates.Count
$payload.candidates = @($selectionCandidates | Select-Object -First 20)

$businessCandidates = @($selectionCandidates | Where-Object { $_.page_kind -eq "business_page" })
$choiceCandidates = $selectionCandidates
if ($businessCandidates.Count -gt 0) {
  $choiceCandidates = $businessCandidates
  $payload.business_candidate_count = $businessCandidates.Count
  $payload.ignored_non_business_candidate_count = [Math]::Max(0, $selectionCandidates.Count - $businessCandidates.Count)
}

$foreground = @($choiceCandidates | Where-Object { $_.is_foreground_process } | Select-Object -First 1)
$intentChoice = $null
if ($choiceCandidates.Count -gt 1 -and $Intent) {
  $intentChoice = Resolve-XinjianUrlByIntent -QueryIntent $Intent -Candidates $choiceCandidates
}
if ($intentChoice -and $intentChoice.url) {
  $payload.ok = $true
  $payload.url = [string]$intentChoice.url
  $payload.resolved_port = if ($intentChoice.port) { [int]$intentChoice.port } else { $null }
  $payload.source = "intent_scored_candidate"
  $payload.confidence = "intent_unique_best_match"
  $payload.reason = "ambiguous_xinjian_windows_resolved_by_intent"
  $payload.intent_resolution = $intentChoice
} elseif ($foreground.Count -gt 0) {
  $payload.ok = $true
  $payload.url = [string]$foreground[0].url
  $payload.resolved_port = if ($foreground[0].port) { [int]$foreground[0].port } else { $null }
  $payload.source = [string]$foreground[0].source
  $payload.confidence = "foreground_window_url"
  $payload.reason = if ($businessCandidates.Count -gt 0) { "foreground_business_xinjian_window" } else { "foreground_xinjian_window" }
} elseif ($choiceCandidates.Count -eq 1) {
  $payload.ok = $true
  $payload.url = [string]$choiceCandidates[0].url
  $payload.resolved_port = if ($choiceCandidates[0].port) { [int]$choiceCandidates[0].port } else { $null }
  $payload.source = [string]$choiceCandidates[0].source
  $payload.confidence = if ($businessCandidates.Count -gt 0) { "single_business_xinjian_candidate" } else { "single_xinjian_candidate" }
  $payload.reason = if ($businessCandidates.Count -gt 0) { "single_business_xinjian_window" } else { "single_xinjian_window" }
} elseif ($choiceCandidates.Count -gt 1) {
  $payload.reason = if ($businessCandidates.Count -gt 0) { "ambiguous_business_xinjian_windows" } else { "ambiguous_xinjian_windows" }
} else {
  $payload.reason = "no_xinjian_window"
}

if ($Json) {
  $payload | ConvertTo-Json -Depth 14
} else {
  if ($payload.ok) {
    Write-Host ("Xinjian URL: {0} ({1})" -f $payload.url, $payload.confidence)
  } else {
    Write-Host ("No unique Xinjian URL resolved: {0}" -f $payload.reason)
  }
}

if ($payload.ok) { exit 0 }
exit 1
