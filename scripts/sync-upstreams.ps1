param(
  [string]$Root = "",
  [string]$UpstreamRoot = "",
  [string[]]$Name = @(),
  [switch]$FetchOnly,
  [switch]$Json
)

$ErrorActionPreference = "Continue"

if (!$Root) {
  $Root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
} else {
  $Root = (Resolve-Path -LiteralPath $Root).Path
}
if (!$UpstreamRoot) {
  $UpstreamRoot = Join-Path $Root ".upstreams"
}

$configPath = Join-Path $Root "references\upstreams.json"
$checkedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
$items = @()

function New-SafeName([string]$Value) {
  $safe = $Value -replace "[^A-Za-z0-9_.-]+", "__"
  return $safe.Trim("_")
}

function Add-Result($Record) {
  $script:items += [pscustomobject]$Record
}

if (!(Test-Path -LiteralPath $configPath)) {
  $result = [ordered]@{
    ok = $false
    synced_at = $checkedAt
    root = $Root
    upstream_root = $UpstreamRoot
    error = "references/upstreams.json not found"
    upstreams = @()
  }
  if ($Json) { $result | ConvertTo-Json -Depth 8 } else { Write-Host "SYNC_UPSTREAMS_FAILED: references/upstreams.json not found" }
  exit 1
}

try {
  $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
} catch {
  $result = [ordered]@{
    ok = $false
    synced_at = $checkedAt
    root = $Root
    upstream_root = $UpstreamRoot
    error = "Failed to parse references/upstreams.json: $($_.Exception.Message)"
    upstreams = @()
  }
  if ($Json) { $result | ConvertTo-Json -Depth 8 } else { Write-Host "SYNC_UPSTREAMS_FAILED: $($result.error)" }
  exit 1
}

$git = Get-Command git -ErrorAction SilentlyContinue
if (!$git) {
  $result = [ordered]@{
    ok = $false
    synced_at = $checkedAt
    root = $Root
    upstream_root = $UpstreamRoot
    error = "git command not found"
    upstreams = @()
  }
  if ($Json) { $result | ConvertTo-Json -Depth 8 } else { Write-Host "SYNC_UPSTREAMS_FAILED: git command not found" }
  exit 1
}

New-Item -ItemType Directory -Force -Path $UpstreamRoot | Out-Null
$resolvedUpstreamRoot = (Resolve-Path -LiteralPath $UpstreamRoot).Path
if (!$resolvedUpstreamRoot.StartsWith($Root, [System.StringComparison]::OrdinalIgnoreCase)) {
  $result = [ordered]@{
    ok = $false
    synced_at = $checkedAt
    root = $Root
    upstream_root = $resolvedUpstreamRoot
    error = "Refusing to sync outside repo root"
    upstreams = @()
  }
  if ($Json) { $result | ConvertTo-Json -Depth 8 } else { Write-Host "SYNC_UPSTREAMS_FAILED: refusing to sync outside repo root" }
  exit 1
}

$filters = @($Name | Where-Object { $_ })
foreach ($upstream in @($config.upstreams)) {
  $upstreamName = [string]$upstream.name
  if ($filters.Count -gt 0 -and $filters -notcontains $upstreamName) { continue }

  $gitUrl = [string]$upstream.git_url
  $branch = [string]$upstream.branch
  $syncMode = [string]$upstream.sync_mode
  if (!$syncMode) { $syncMode = if ($gitUrl) { "mirror" } else { "manual" } }
  $target = Join-Path $resolvedUpstreamRoot (New-SafeName $upstreamName)

  $record = [ordered]@{
    name = $upstreamName
    type = [string]$upstream.type
    sync_mode = $syncMode
    license = [string]$upstream.license
    git_url = $gitUrl
    branch = $branch
    path = $target
    ok = $false
    skipped = $false
    dirty = $false
    current_commit = ""
    remote_commit = ""
    action = ""
    warning = ""
    error = ""
  }

  if (!$gitUrl) {
    $record.skipped = $true
    $record.action = "manual_review"
    $record.warning = "No git_url recorded. Review URL manually: $($upstream.url)"
    Add-Result $record
    continue
  }

  if (!$branch) { $branch = "HEAD" }
  $ref = if ($branch -eq "HEAD") { "HEAD" } else { "refs/heads/$branch" }

  $remoteText = ""
  try {
    $remoteOutput = @(& git ls-remote $gitUrl $ref 2>&1)
    $remoteText = ($remoteOutput | Out-String).Trim()
    if ($LASTEXITCODE -eq 0 -and $remoteText) {
      $firstLine = @($remoteText -split "`r?`n")[0]
      $parts = @($firstLine -split "\s+")
      if ($parts.Count -gt 0 -and $parts[0] -match "^[0-9a-f]{40}$") {
        $record.remote_commit = $parts[0]
      }
    }
  } catch {
    $record.error = $_.Exception.Message
  }
  if ($record.error -or !$record.remote_commit) {
    if (!$record.error) { $record.error = "Unable to resolve remote commit: $remoteText" }
    Add-Result $record
    continue
  }

  if (!(Test-Path -LiteralPath $target)) {
    try {
      if ($branch -eq "HEAD") {
        & git clone $gitUrl $target 2>&1 | Out-Null
      } else {
        & git clone --branch $branch --single-branch $gitUrl $target 2>&1 | Out-Null
      }
      if ($LASTEXITCODE -ne 0) {
        $record.error = "git clone failed"
      } else {
        $record.action = "cloned"
      }
    } catch {
      $record.error = $_.Exception.Message
    }
  } elseif (!(Test-Path -LiteralPath (Join-Path $target ".git"))) {
    $record.error = "Target exists but is not a git repository"
  } else {
    try {
      $status = (& git -C $target status --short 2>$null | Out-String).Trim()
      $record.dirty = [bool]$status
      & git -C $target fetch --prune origin 2>&1 | Out-Null
      if ($LASTEXITCODE -ne 0) {
        $record.error = "git fetch failed"
      } elseif ($record.dirty -or $FetchOnly) {
        $record.action = if ($record.dirty) { "fetched_dirty_not_updated" } else { "fetched" }
        if ($record.dirty) { $record.warning = "Local mirror has uncommitted changes; fetched only." }
      } else {
        if ($branch -ne "HEAD") {
          & git -C $target checkout $branch 2>&1 | Out-Null
          if ($LASTEXITCODE -ne 0) { $record.error = "git checkout failed" }
        }
        if (!$record.error) {
          & git -C $target pull --ff-only origin $branch 2>&1 | Out-Null
          if ($LASTEXITCODE -ne 0) {
            $record.error = "git pull --ff-only failed"
          } else {
            $record.action = "updated"
          }
        }
      }
    } catch {
      $record.error = $_.Exception.Message
    }
  }

  if (!$record.error -and (Test-Path -LiteralPath (Join-Path $target ".git"))) {
    $head = (& git -C $target rev-parse HEAD 2>$null | Out-String).Trim()
    $record.current_commit = $head
    $record.ok = [bool]$head
    if (!$record.action) { $record.action = "checked" }
    if ($syncMode -eq "mirror-reference-only") {
      $record.warning = "Reference-only mirror. Do not copy code into the public repo without permission."
    }
  }

  Add-Result $record
}

$statusPath = Join-Path $resolvedUpstreamRoot "upstreams.status.json"
$hasErrors = @($items | Where-Object { !$_.ok -and !$_.skipped }).Count -gt 0
$result = [ordered]@{
  ok = !$hasErrors
  synced_at = $checkedAt
  root = $Root
  upstream_root = $resolvedUpstreamRoot
  status_path = $statusPath
  upstreams = @($items)
}

try {
  $result | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $statusPath -Encoding UTF8
} catch {
}

if ($Json) {
  $result | ConvertTo-Json -Depth 10
} else {
  if ($result.ok) { Write-Host "SYNC_UPSTREAMS_OK" } else { Write-Host "SYNC_UPSTREAMS_HAS_ERRORS" }
  Write-Host ("Upstream root: {0}" -f $resolvedUpstreamRoot)
  foreach ($item in $items) {
    if ($item.ok) {
      Write-Host ("[ok] {0}: {1} {2}" -f $item.name, $item.action, $item.current_commit)
      if ($item.warning) { Write-Host ("     warning: {0}" -f $item.warning) }
    } elseif ($item.skipped) {
      Write-Host ("[manual] {0}: {1}" -f $item.name, $item.warning)
    } else {
      Write-Host ("[error] {0}: {1}" -f $item.name, $item.error)
    }
  }
}

if ($hasErrors) { exit 1 }
