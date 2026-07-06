$ErrorActionPreference = "Stop"

$skillName = "ziniao-ops"
$legacySkillNames = @("ziniao-seller-ops", "dianpu-open-store")
$packageRoot = (Resolve-Path -LiteralPath $PSScriptRoot).Path
$source = Join-Path $PSScriptRoot "codex-skill\$skillName"
$codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE ".codex" }
$targetRoot = Join-Path $codexHome "skills"
$target = Join-Path $targetRoot $skillName
$backupRoot = Join-Path $codexHome "skill-backups"
$configPath = Join-Path $codexHome "$skillName.json"
$ziniaoConfigPath = Join-Path $packageRoot "ziniao.local.json"
$shopsPath = Join-Path $packageRoot "shops.json"

if (!(Test-Path $source)) {
  throw "Skill source not found: $source"
}

function Test-IsWindows {
  $var = Get-Variable IsWindows -ErrorAction SilentlyContinue
  if ($var) { return [bool]$var.Value }
  return ($env:OS -eq "Windows_NT")
}

function Get-FreeBytesForPath([string]$Path) {
  try {
    $qualified = [System.IO.Path]::GetFullPath($Path)
    $rootPath = [System.IO.Path]::GetPathRoot($qualified)
    if (!$rootPath) { return $null }
    $driveName = $rootPath.TrimEnd("\")
    $drive = Get-CimInstance Win32_LogicalDisk -Filter ("DeviceID='{0}'" -f $driveName.Replace("'", "''")) -ErrorAction SilentlyContinue
    if ($drive) { return [double]$drive.FreeSpace }
  } catch {
  }
  return $null
}

function Move-OldBackupsIfLowSpace {
  $freeBytes = Get-FreeBytesForPath $codexHome
  if ($freeBytes -eq $null -or $freeBytes -ge 20MB) { return }
  if (!(Test-Path -LiteralPath $backupRoot)) { return }

  $localBackupRoot = Join-Path $packageRoot ".ziniao-ops\codex-skill-backups"
  New-Item -ItemType Directory -Force -Path $localBackupRoot | Out-Null
  $backupNames = @($skillName) + $legacySkillNames
  foreach ($name in $backupNames) {
    Get-ChildItem -LiteralPath $backupRoot -Directory -Filter "$name.bak-*" -ErrorAction SilentlyContinue | ForEach-Object {
      $dest = Join-Path $localBackupRoot $_.Name
      if (Test-Path -LiteralPath $dest) {
        $dest = Join-Path $localBackupRoot ($_.Name + "-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
      }
      Move-Item -LiteralPath $_.FullName -Destination $dest
      Write-Host "Moved old skill backup to local package cache: $dest"
    }
  }
}

function Remove-InstallTargetIfPresent {
  if (!(Test-Path -LiteralPath $target)) { return }
  $resolvedTargetRoot = (Resolve-Path -LiteralPath $targetRoot).Path
  $resolvedTarget = (Resolve-Path -LiteralPath $target).Path
  if (!$resolvedTarget.StartsWith($resolvedTargetRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to remove unexpected target outside Codex skills folder: $resolvedTarget"
  }
  Remove-Item -LiteralPath $resolvedTarget -Recurse -Force
}

function Install-SkillTarget {
  try {
    Copy-Item -LiteralPath $source -Destination $target -Recurse
    return "copy"
  } catch {
    $copyError = $_.Exception.Message
    Write-Warning "Skill copy failed: $copyError"
    Write-Warning "Falling back to a directory junction to reduce Codex home disk usage."
    Remove-InstallTargetIfPresent
    if (!(Test-IsWindows)) {
      throw "Skill copy failed and junction fallback is Windows-only: $copyError"
    }
    New-Item -ItemType Junction -Path $target -Target $source | Out-Null
    return "junction"
  }
}

function Find-ZiniaoExe {
  if (!(Test-IsWindows)) { return "" }
  $candidates = New-Object System.Collections.Generic.List[string]
  foreach ($envName in @("ZINIAO_CLIENT_PATH", "ZINIAO_PATH")) {
    $value = [Environment]::GetEnvironmentVariable($envName)
    if ($value) { $candidates.Add([Environment]::ExpandEnvironmentVariables($value)) }
  }
  foreach ($root in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:LOCALAPPDATA, $env:APPDATA, "C:\", "D:\", "E:\", "F:\")) {
    if (!$root -or !(Test-Path -LiteralPath $root)) { continue }
    foreach ($rel in @("ZiNiao\ziniao.exe", "ZiNiao\ZiNiao.exe", "Ziniao\ziniao.exe", "Ziniao\Ziniao.exe", "紫鸟\ziniao.exe", "紫鸟\ZiNiao.exe")) {
      $candidates.Add((Join-Path $root $rel))
    }
  }
  foreach ($dir in @(
    [Environment]::GetFolderPath("Desktop"),
    [Environment]::GetFolderPath("CommonDesktopDirectory"),
    [Environment]::GetFolderPath("StartMenu"),
    [Environment]::GetFolderPath("CommonStartMenu")
  )) {
    if (!$dir -or !(Test-Path -LiteralPath $dir)) { continue }
    Get-ChildItem -LiteralPath $dir -Recurse -Filter *.lnk -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -match "紫鸟|Ziniao|ZiNiao" } |
      ForEach-Object {
        try {
          $shell = New-Object -ComObject WScript.Shell
          $shortcut = $shell.CreateShortcut($_.FullName)
          if ($shortcut.TargetPath) { $candidates.Add($shortcut.TargetPath) }
        } catch {
        }
      }
  }
  foreach ($candidate in $candidates) {
    if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
      return (Resolve-Path -LiteralPath $candidate).Path
    }
  }
  $cmd = Get-Command ziniao.exe -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  return ""
}

New-Item -ItemType Directory -Force -Path $targetRoot,$backupRoot | Out-Null
Move-OldBackupsIfLowSpace
foreach ($name in @($skillName) + $legacySkillNames) {
  Get-ChildItem -LiteralPath $targetRoot -Directory -Filter "$name.bak-*" -ErrorAction SilentlyContinue | ForEach-Object {
    $legacyBackup = Join-Path $backupRoot $_.Name
    if (Test-Path -LiteralPath $legacyBackup) {
      $legacyBackup = Join-Path $backupRoot ($_.Name + "-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
    }
    Move-Item -LiteralPath $_.FullName -Destination $legacyBackup
    Write-Host "Moved old backup out of skills folder: $legacyBackup"
  }
}
foreach ($legacyName in $legacySkillNames) {
  $legacyTarget = Join-Path $targetRoot $legacyName
  if (Test-Path -LiteralPath $legacyTarget) {
    $legacyBackup = Join-Path $backupRoot ("$legacyName.bak-$(Get-Date -Format yyyyMMddHHmmss)")
    Move-Item -LiteralPath $legacyTarget -Destination $legacyBackup
    Write-Host "Legacy skill backed up: $legacyBackup"
  }
}
if (Test-Path $target) {
  $backup = Join-Path $backupRoot ("$skillName.bak-$(Get-Date -Format yyyyMMddHHmmss)")
  Move-Item -LiteralPath $target -Destination $backup
  Write-Host "Existing skill backed up: $backup"
}

$installMode = Install-SkillTarget
$config = [ordered]@{
  package_root = $packageRoot
  installed_at = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  skill_name = $skillName
  install_mode = $installMode
  previous_names = $legacySkillNames
}
$config | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $configPath -Encoding UTF8

if (!(Test-Path -LiteralPath $ziniaoConfigPath)) {
  $ziniaoPath = Find-ZiniaoExe
  $ziniaoConfig = [ordered]@{
    webdriver_port = 16851
    client_path = $ziniaoPath
    note = "Local-only config. Empty client_path is OK when Ziniao is already running or auto-detection works. Do not store passwords here."
  }
  $ziniaoConfig | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $ziniaoConfigPath -Encoding UTF8
  if ($ziniaoPath) {
    Write-Host "Detected Ziniao: $ziniaoPath"
  } elseif (!(Test-IsWindows)) {
    Write-Host "Non-Windows system detected. Skill can install, but Ziniao desktop automation needs Windows."
  } else {
    Write-Host "Ziniao executable was not detected. This is OK if Ziniao is already open; otherwise edit ziniao.local.json client_path."
  }
} else {
  Write-Host "Existing local Ziniao config kept: $ziniaoConfigPath"
}

if (!(Test-Path -LiteralPath $shopsPath)) {
  $shopsConfig = [ordered]@{
    version = 1
    updated_at = (Get-Date).ToString("yyyy-MM-dd")
    shops = @()
  }
  $shopsConfig | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $shopsPath -Encoding UTF8
  Write-Host "Created empty local shop list: $shopsPath"
} else {
  Write-Host "Existing local shop list kept: $shopsPath"
}

Write-Host "Installed Codex skill: $target"
Write-Host "Wrote package config: $configPath"
Write-Host "Package root: $packageRoot"
Write-Host "Restart Codex and ask: 打开 <店铺关键词> 操作一下 / 全部数据 / 订单数据 / 广告数据"
Write-Host "Codex should use operate-store.ps1 for normal work. For opening only, open-store.ps1 first reuses the current Ziniao/store window, then falls back to login handoff, shop scan, and automatic continue."
Write-Host "Optional pre-check: powershell -NoProfile -ExecutionPolicy Bypass -File .\setup-ziniao.ps1"
Write-Host "If this computer is different and opening still fails, give 本机适配修复提示词.txt to this computer's Codex."
