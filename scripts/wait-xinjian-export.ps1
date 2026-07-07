[CmdletBinding(PositionalBinding = $false)]
param(
  [string[]]$StoreName = @(),
  [string]$WatchRoot = "",
  [int]$TimeoutSec = 300,
  [int]$StableSec = 3,
  [int]$Days = 7,
  [string]$StartDate = "",
  [string]$EndDate = "",
  [string]$OutputPath = "",
  [string]$ExcelOutputPath = "",
  [switch]$Json
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path

if (!$WatchRoot) {
  $workspaceParent = Split-Path -Parent $root
  $userDataRoot = Split-Path -Parent $workspaceParent
  $candidate = Join-Path $userDataRoot "Downloads"
  if (Test-Path -LiteralPath $candidate) {
    $WatchRoot = $candidate
  } else {
    $WatchRoot = Join-Path ([Environment]::GetFolderPath("UserProfile")) "Downloads"
  }
}
$WatchRoot = (Resolve-Path -LiteralPath $WatchRoot).Path

$StoreName = @(
  foreach ($name in $StoreName) {
    if ($name) {
      $name -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    }
  }
)

$start = Get-Date
$extensions = @(".xlsx", ".csv", ".json")

function Get-CandidateFiles {
  Get-ChildItem -LiteralPath $WatchRoot -File -ErrorAction SilentlyContinue |
    Where-Object {
      $extensions -contains $_.Extension.ToLowerInvariant() -and
      $_.LastWriteTime -ge $start.AddSeconds(-2) -and
      $_.Name -notmatch "\.crdownload$|\.tmp$|\.part$"
    } |
    Sort-Object LastWriteTime -Descending
}

function Test-FileStable([System.IO.FileInfo]$File) {
  $first = $File.Length
  Start-Sleep -Seconds $StableSec
  $again = Get-Item -LiteralPath $File.FullName -ErrorAction SilentlyContinue
  if (!$again) { return $false }
  return ($again.Length -eq $first -and $again.Length -gt 0)
}

$chosen = $null
$deadline = $start.AddSeconds([Math]::Max($TimeoutSec, 1))
while ((Get-Date) -lt $deadline) {
  foreach ($file in @(Get-CandidateFiles)) {
    if (Test-FileStable $file) {
      $chosen = Get-Item -LiteralPath $file.FullName
      break
    }
  }
  if ($chosen) { break }
  Start-Sleep -Seconds 2
}

if (!$chosen) {
  $result = [ordered]@{
    ok = $false
    status = "timeout"
    watch_root = $WatchRoot
    timeout_sec = $TimeoutSec
    message = "No new stable export file was found."
  }
  if ($Json) {
    $result | ConvertTo-Json -Depth 6
    exit 0
  } else {
    Write-Host "XINJIAN_EXPORT_WAIT_TIMEOUT"
    Write-Host "No new stable export file was found in: $WatchRoot"
    exit 2
  }
}

$argsList = @(
  "-ExecutionPolicy", "Bypass",
  "-File", (Join-Path $PSScriptRoot "xinjian-erp-ad-hourly.ps1"),
  "-InputPath", $chosen.FullName,
  "-Days", "$Days",
  "-Json"
)
if ($StoreName -and $StoreName.Count -gt 0) {
  $argsList += @("-StoreName", ($StoreName -join ","))
}
if ($StartDate) { $argsList += @("-StartDate", $StartDate) }
if ($EndDate) { $argsList += @("-EndDate", $EndDate) }
if ($OutputPath) { $argsList += @("-OutputPath", $OutputPath) }
if ($ExcelOutputPath) { $argsList += @("-ExcelOutputPath", $ExcelOutputPath) }

$raw = & powershell @argsList
$exit = $LASTEXITCODE
if ($Json) {
  $analysis = $null
  try {
    $analysis = ($raw | Out-String | ConvertFrom-Json)
  } catch {
    $analysis = [pscustomobject]@{
      ok = $false
      parse_failed = $true
      raw = ($raw | Out-String)
    }
  }
  $analysisOk = [bool]$analysis.ok
  $outer = [ordered]@{
    ok = $analysisOk
    status = if ($analysisOk) { "analyzed" } else { "analysis_failed" }
    export_path = $chosen.FullName
    analysis = $analysis
  }
  $outer | ConvertTo-Json -Depth 12
  exit 0
} else {
  $raw
}
exit $exit
