param(
  [string]$Root = "",
  [switch]$Json
)

$ErrorActionPreference = "Continue"

if (!$Root) {
  $Root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
} else {
  $Root = (Resolve-Path -LiteralPath $Root).Path
}

$upstreamsPath = Join-Path $Root "references\upstreams.json"
$checkedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
$items = @()

if (!(Test-Path -LiteralPath $upstreamsPath)) {
  $result = [ordered]@{
    ok = $false
    checked_at = $checkedAt
    root = $Root
    error = "references/upstreams.json not found"
    upstreams = @()
  }
  if ($Json) {
    $result | ConvertTo-Json -Depth 8
  } else {
    Write-Host "UPSTREAM_CHECK_FAILED: references/upstreams.json not found"
  }
  exit 1
}

try {
  $data = Get-Content -LiteralPath $upstreamsPath -Raw | ConvertFrom-Json
} catch {
  $result = [ordered]@{
    ok = $false
    checked_at = $checkedAt
    root = $Root
    error = "Failed to parse references/upstreams.json: $($_.Exception.Message)"
    upstreams = @()
  }
  if ($Json) {
    $result | ConvertTo-Json -Depth 8
  } else {
    Write-Host "UPSTREAM_CHECK_FAILED: $($result.error)"
  }
  exit 1
}

$git = Get-Command git -ErrorAction SilentlyContinue

foreach ($upstream in @($data.upstreams)) {
  $name = [string]$upstream.name
  $url = [string]$upstream.url
  $gitUrl = [string]$upstream.git_url
  $branch = [string]$upstream.branch
  $record = [ordered]@{
    name = $name
    type = [string]$upstream.type
    url = $url
    git_url = $gitUrl
    branch = $branch
    latest_commit = ""
    ok = $false
    skipped = $false
    error = ""
  }

  if (!$gitUrl) {
    $record.skipped = $true
    $record.error = "manual_review_source"
    $items += [pscustomobject]$record
    continue
  }

  if (!$git) {
    $record.error = "git_missing"
    $items += [pscustomobject]$record
    continue
  }

  if (!$branch) { $branch = "HEAD" }
  $ref = if ($branch -eq "HEAD") { "HEAD" } else { "refs/heads/$branch" }

  try {
    $output = @(& git ls-remote $gitUrl $ref 2>&1)
    $text = ($output | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) {
      $record.error = $text
    } elseif (!$text) {
      $record.error = "empty_ls_remote_result"
    } else {
      $firstLine = @($text -split "`r?`n")[0]
      $parts = @($firstLine -split "\s+")
      if ($parts.Count -gt 0 -and $parts[0] -match "^[0-9a-f]{40}$") {
        $record.latest_commit = $parts[0]
        $record.ok = $true
      } else {
        $record.error = "unexpected_ls_remote_output: $firstLine"
      }
    }
  } catch {
    $record.error = $_.Exception.Message
  }

  $items += [pscustomobject]$record
}

$hasErrors = @($items | Where-Object { !$_.ok -and !$_.skipped }).Count -gt 0
$result = [ordered]@{
  ok = !$hasErrors
  checked_at = $checkedAt
  root = $Root
  own_repository = $data.own_repository
  upstreams = @($items)
}

if ($Json) {
  $result | ConvertTo-Json -Depth 8
} else {
  if ($result.ok) {
    Write-Host "UPSTREAM_CHECK_OK"
  } else {
    Write-Host "UPSTREAM_CHECK_HAS_ERRORS"
  }
  Write-Host ("Own repo: {0} ({1})" -f $data.own_repository.name, $data.own_repository.url)
  foreach ($item in $items) {
    if ($item.ok) {
      Write-Host ("[ok] {0} {1} {2}" -f $item.name, $item.branch, $item.latest_commit)
    } elseif ($item.skipped) {
      Write-Host ("[manual] {0} {1}" -f $item.name, $item.url)
    } else {
      Write-Host ("[error] {0}: {1}" -f $item.name, $item.error)
    }
  }
}

if ($hasErrors) { exit 1 }
