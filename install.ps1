param(
  [switch]$InstallLazadaDeps,
  [switch]$SkipGuiDeps,
  [switch]$InstallOptionalTools,
  [switch]$SkipOptionalTools,
  [switch]$SkipZiniaoSetup,
  [switch]$NonInteractive,
  [switch]$InstallMissingRuntimes,
  [switch]$SkipMissingRuntimeInstall,
  [string]$LocalToolsRoot = "",
  [int]$LoginTimeoutSeconds = 600
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath $PSScriptRoot).Path
$isInteractive = (!$NonInteractive -and [Environment]::UserInteractive)

function Test-IsWindows {
  $var = Get-Variable IsWindows -ErrorAction SilentlyContinue
  if ($var) { return [bool]$var.Value }
  return ($env:OS -eq "Windows_NT")
}

function Ask-YesNo([string]$Question, [bool]$DefaultYes = $true) {
  if (!$isInteractive) { return $DefaultYes }
  $suffix = if ($DefaultYes) { "[Y/n]" } else { "[y/N]" }
  while ($true) {
    $answer = Read-Host "$Question $suffix"
    if ([string]::IsNullOrWhiteSpace($answer)) { return $DefaultYes }
    switch -Regex ($answer.Trim()) {
      "^(y|yes|是|好|可以|确认|装|安装)$" { return $true }
      "^(n|no|否|不|不用|跳过)$" { return $false }
      default { Write-Host "请输入 Y 或 N。" }
    }
  }
}

function Ask-Path([string]$Question, [string]$DefaultPath) {
  if (!$isInteractive) { return $DefaultPath }
  $answer = Read-Host "$Question`n默认: $DefaultPath`n直接回车确认，或输入新的完整目录"
  if ([string]::IsNullOrWhiteSpace($answer)) { return $DefaultPath }
  return [Environment]::ExpandEnvironmentVariables($answer.Trim('" '))
}

function Format-Bytes([double]$Bytes) {
  if ($Bytes -ge 1TB) { return ("{0:N1} TB" -f ($Bytes / 1TB)) }
  if ($Bytes -ge 1GB) { return ("{0:N1} GB" -f ($Bytes / 1GB)) }
  if ($Bytes -ge 1MB) { return ("{0:N1} MB" -f ($Bytes / 1MB)) }
  return ("{0:N0} B" -f $Bytes)
}

function Show-DriveSummary {
  if (!(Test-IsWindows)) { return }
  Write-Host ""
  Write-Host "可用磁盘空间："
  Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction SilentlyContinue |
    Sort-Object DeviceID |
    ForEach-Object {
      Write-Host ("- {0} 剩余 {1} / 总计 {2}" -f $_.DeviceID, (Format-Bytes $_.FreeSpace), (Format-Bytes $_.Size))
    }
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

function Ensure-Directory([string]$Path) {
  if (!(Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
  }
}

function Refresh-Path {
  $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
  $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
  $env:Path = @($machinePath, $userPath) -join ";"
}

function Test-AnyCommand([string[]]$Names) {
  foreach ($name in $Names) {
    if (Get-Command $name -ErrorAction SilentlyContinue) { return $true }
  }
  return $false
}

function Install-WingetPackage([string]$Id, [string]$Name) {
  if (!(Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Warning "winget 不可用，无法自动安装 $Name。请手动安装后重跑 install.ps1。"
    return $false
  }
  Write-Host "正在通过 winget 安装 $Name ..."
  winget install --id $Id -e --accept-package-agreements --accept-source-agreements
  if ($LASTEXITCODE -ne 0) {
    Write-Warning "$Name 自动安装失败，请手动安装后重跑 install.ps1。"
    return $false
  }
  Refresh-Path
  return $true
}

function Invoke-ChildScript([string]$ScriptPath, [string[]]$Arguments = @(), [switch]$WarnOnly) {
  if (!(Test-Path -LiteralPath $ScriptPath)) {
    if ($WarnOnly) {
      Write-Warning "脚本不存在: $ScriptPath"
      return $false
    }
    throw "Script not found: $ScriptPath"
  }
  powershell -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @Arguments
  if ($LASTEXITCODE -ne 0) {
    if ($WarnOnly) {
      Write-Warning "脚本执行未完成，exit code: $LASTEXITCODE, script: $ScriptPath"
      return $false
    }
    throw "Script failed with exit code $LASTEXITCODE`: $ScriptPath"
  }
  return $true
}

Write-Host "Ziniao Ops installer"
Write-Host "Package root: $root"
Write-Host "Skill name: ziniao-ops"

if (!(Test-IsWindows)) {
  Write-Warning "当前不是 Windows。可以安装 skill 和文档，但紫鸟桌面自动开店只支持 Windows。"
}

$installSkill = Join-Path $root "install-codex-skill.ps1"
if (!(Test-Path -LiteralPath $installSkill)) {
  throw "install-codex-skill.ps1 not found. Please run this script from the extracted ziniao-ops folder."
}

$installGuiDeps = $false
if (!$SkipGuiDeps) {
  if ($InstallLazadaDeps) {
    $installGuiDeps = $true
  } elseif ($isInteractive) {
    $installGuiDeps = Ask-YesNo "是否安装紫鸟 GUI/Lazada 精准打开依赖 pywinauto？建议安装，setup-ziniao 和 Lazada GUI 兜底会用到。" $true
  } else {
    $installGuiDeps = $false
  }
}

$installUpstreams = $false
if ($SkipOptionalTools) {
  $installUpstreams = $false
} elseif ($InstallOptionalTools) {
  $installUpstreams = $true
} elseif ($isInteractive) {
  $installUpstreams = Ask-YesNo "是否安装可选上游增强工具？包含 ziniao CLI、auto-ziniao、BrowserMCP server、Vibe Seller 和 Playwright 浏览器文件，体积较大。" $true
}

if ($installUpstreams) {
  Write-Host "注意：LinkFox、Seller Sprite、Keepa、VOC.AI、ShipStation、TaxJar 等外部电商 SaaS/API 只会记录和检测，不会静默安装或自动上传店铺数据。"
}

if ($installGuiDeps -or $installUpstreams) {
  Show-DriveSummary
  $defaultToolsRoot = Join-Path $root ".ziniao-ops"
  if (!$LocalToolsRoot) {
    $LocalToolsRoot = Ask-Path "依赖、虚拟环境、浏览器文件要安装到哪个目录？" $defaultToolsRoot
  }
  Ensure-Directory $LocalToolsRoot
  $freeBytes = Get-FreeBytesForPath $LocalToolsRoot
  if ($freeBytes -ne $null) {
    Write-Host ("依赖目录: {0}" -f $LocalToolsRoot)
    Write-Host ("该磁盘剩余空间: {0}" -f (Format-Bytes $freeBytes))
    if ($installUpstreams -and $freeBytes -lt 4GB) {
      Write-Warning "可选上游工具和 Playwright 浏览器建议至少预留 4GB。当前目录所在磁盘空间偏低。"
      if ($isInteractive -and !(Ask-YesNo "仍然继续安装到这个目录吗？" $false)) {
        $LocalToolsRoot = Ask-Path "请输入新的依赖安装目录" $defaultToolsRoot
        Ensure-Directory $LocalToolsRoot
      }
    } elseif ($installGuiDeps -and $freeBytes -lt 1GB) {
      Write-Warning "本地 Python 依赖建议至少预留 1GB。当前目录所在磁盘空间偏低。"
    }
  }
}

$needPython = $true
$needNode = $installUpstreams
$needGit = $installUpstreams
$allowRuntimeInstall = $InstallMissingRuntimes
if (!$allowRuntimeInstall -and !$SkipMissingRuntimeInstall -and $isInteractive) {
  $allowRuntimeInstall = Ask-YesNo "如果缺 Python/Node/Git，是否允许安装器尝试用 winget 自动安装？" $true
}

if ($needPython -and !(Test-AnyCommand @("py", "python"))) {
  Write-Warning "未检测到 Python 3。紫鸟扫描、开店脚本和 GUI 依赖需要 Python。"
  if ($allowRuntimeInstall) {
    Install-WingetPackage "Python.Python.3.12" "Python 3.12" | Out-Null
  }
}

if ($needNode -and !(Test-AnyCommand @("npm"))) {
  Write-Warning "未检测到 Node.js/npm。auto-ziniao 和 BrowserMCP server 安装需要 npm。"
  if ($allowRuntimeInstall) {
    Install-WingetPackage "OpenJS.NodeJS.LTS" "Node.js LTS" | Out-Null
  }
}

if ($needGit -and !(Test-AnyCommand @("git"))) {
  Write-Warning "未检测到 Git。上游镜像同步需要 Git。"
  if ($allowRuntimeInstall) {
    Install-WingetPackage "Git.Git" "Git" | Out-Null
  }
}

Refresh-Path

Write-Host ""
Write-Host "Installing Codex skill..."
Invoke-ChildScript $installSkill | Out-Null

if ($installGuiDeps) {
  Write-Host ""
  Write-Host "Installing local GUI/Python dependencies..."
  $deps = Join-Path $root "install-python-deps.ps1"
  $argsList = @()
  if ($LocalToolsRoot) { $argsList += @("-LocalStateRoot", $LocalToolsRoot) }
  Invoke-ChildScript $deps $argsList -WarnOnly | Out-Null
}

if ($installUpstreams) {
  Write-Host ""
  Write-Host "Installing optional upstream tools..."
  $upstreamInstaller = Join-Path $root "scripts\install-upstream-tools.ps1"
  $argsList = @()
  if ($LocalToolsRoot) { $argsList += @("-LocalStateRoot", $LocalToolsRoot) }
  Invoke-ChildScript $upstreamInstaller $argsList -WarnOnly | Out-Null
}

if (!$SkipZiniaoSetup) {
  $setupZiniao = Join-Path $root "setup-ziniao.ps1"
  if (Test-Path -LiteralPath $setupZiniao) {
    Write-Host ""
    Write-Host "Preparing local Ziniao session..."
    Write-Host "If Ziniao asks for login or verification, finish it in the Ziniao window. The script will continue after login."
    Invoke-ChildScript $setupZiniao @("-LoginTimeoutSeconds", ([string]$LoginTimeoutSeconds)) -WarnOnly | Out-Null
  }
}

$diagnose = Join-Path $root "diagnose-local.ps1"
if (Test-Path -LiteralPath $diagnose) {
  Write-Host ""
  Write-Host "Running local diagnosis..."
  powershell -NoProfile -ExecutionPolicy Bypass -File $diagnose
}

$status = Join-Path $root "scripts\status-upstream-adapters.ps1"
if (Test-Path -LiteralPath $status) {
  Write-Host ""
  Write-Host "Optional upstream adapter status..."
  powershell -NoProfile -ExecutionPolicy Bypass -File $status
}

$ecommerceStatus = Join-Path $root "scripts\check-ecommerce-tools.ps1"
if (Test-Path -LiteralPath $ecommerceStatus) {
  Write-Host ""
  Write-Host "Ecommerce platform/API/tool catalog status..."
  powershell -NoProfile -ExecutionPolicy Bypass -File $ecommerceStatus -TimeoutSec 8
}

Write-Host ""
Write-Host "Install finished."
Write-Host "Next:"
Write-Host "1. Restart Codex."
Write-Host "2. Ask Codex: 打开 <店铺关键词> 操作一下 / 全部数据 / 订单数据 / 广告数据"
Write-Host "3. For normal operations Codex should use operate-store.ps1; if a login page appears, complete login locally and run the same sentence again."
