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

function Test-Mirror($SafeName) {
  $path = Join-Path (Join-Path $Root ".upstreams") $SafeName
  return [ordered]@{
    path = $path
    exists = (Test-Path -LiteralPath (Join-Path $path ".git"))
  }
}

function Resolve-RepoPath([string]$Path) {
  if (!$Path) { return "" }
  $expanded = [Environment]::ExpandEnvironmentVariables($Path)
  if (!$expanded) { return "" }
  if ([System.IO.Path]::IsPathRooted($expanded)) {
    return [System.IO.Path]::GetFullPath($expanded)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $Root $expanded))
}

function Get-LocalStateRoot {
  $defaultState = Join-Path $Root ".ziniao-ops"
  $cfgPath = Join-Path $Root "ziniao.local.json"
  if (Test-Path -LiteralPath $cfgPath) {
    try {
      $cfg = Get-Content -LiteralPath $cfgPath -Raw | ConvertFrom-Json
      if ($cfg.local_state_root) {
        return Resolve-RepoPath ([string]$cfg.local_state_root)
      }
    } catch {
    }
  }
  return $defaultState
}

function Get-UniqueExistingOrCandidateDirs([string[]]$Dirs) {
  $seen = @{}
  $result = @()
  foreach ($dir in $Dirs) {
    if (!$dir) { continue }
    $expanded = Resolve-RepoPath $dir
    if (!$expanded) { continue }
    $key = $expanded.ToLowerInvariant()
    if ($seen.ContainsKey($key)) { continue }
    $seen[$key] = $true
    $result += $expanded
  }
  return $result
}

function Get-ToolCommand {
  param(
    [string[]]$Names,
    [string[]]$ExtraPaths = @()
  )

  $extensions = @("", ".exe", ".cmd", ".bat", ".ps1")
  foreach ($dir in $ExtraPaths) {
    if (!$dir) { continue }
    foreach ($name in $Names) {
      foreach ($ext in $extensions) {
        $candidate = Join-Path $dir ($name + $ext)
        if (Test-Path -LiteralPath $candidate) {
          return (Resolve-Path -LiteralPath $candidate).Path
        }
      }
    }
  }

  foreach ($name in $Names) {
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
  }

  return ""
}

function Get-NpmGlobalPrefix {
  $cfgPath = Join-Path $Root "ziniao.local.json"
  if (Test-Path -LiteralPath $cfgPath) {
    try {
      $cfg = Get-Content -LiteralPath $cfgPath -Raw | ConvertFrom-Json
      if ($cfg.npm_prefix) {
        return Resolve-RepoPath ([string]$cfg.npm_prefix)
      }
    } catch {
    }
  }
  try {
    $prefix = (& npm prefix -g 2>$null | Select-Object -First 1)
    if ($LASTEXITCODE -eq 0 -and $prefix) { return $prefix.Trim() }
  } catch {
  }
  return ""
}

function Get-PythonUserScriptDirs {
  $dirs = @()
  if ($env:APPDATA) {
    $dirs += (Join-Path $env:APPDATA "Python\Python312\Scripts")
    $dirs += (Join-Path $env:APPDATA "Python\Python311\Scripts")
    $dirs += (Join-Path $env:APPDATA "Python\Python310\Scripts")
  }
  try {
    $base = (& py -3 -m site --user-base 2>$null | Select-Object -First 1)
    if ($LASTEXITCODE -eq 0 -and $base) { $dirs += (Join-Path $base.Trim() "Scripts") }
  } catch {
  }
  try {
    $base = (& python -m site --user-base 2>$null | Select-Object -First 1)
    if ($LASTEXITCODE -eq 0 -and $base) { $dirs += (Join-Path $base.Trim() "Scripts") }
  } catch {
  }
  return Get-UniqueExistingOrCandidateDirs $dirs
}

$npmPrefix = Get-NpmGlobalPrefix
$pythonScriptDirs = Get-PythonUserScriptDirs
$localStateRoot = Get-LocalStateRoot
$localBin = Join-Path $localStateRoot "bin"
$ziniaoCliVenvScripts = Join-Path $localStateRoot "tools\ziniao-cli-venv\Scripts"
$runtimeVenvScripts = Join-Path $localStateRoot "tools\python-venv\Scripts"
$vibeSellerVenvScripts = Join-Path $localStateRoot "tools\vibe-seller-venv\Scripts"
$playwrightBrowsers = Join-Path $localStateRoot "tools\playwright-browsers"

$ziniao = Get-ToolCommand -Names @("ziniao") -ExtraPaths (@($ziniaoCliVenvScripts, $localBin) + $pythonScriptDirs)
$autoZiniao = Get-ToolCommand -Names @("auto-ziniao") -ExtraPaths @($npmPrefix)
$browserMcp = Get-ToolCommand -Names @("mcp-server-browsermcp") -ExtraPaths @($npmPrefix)
$chromeDevToolsMcp = Get-ToolCommand -Names @("chrome-devtools-mcp", "chrome-devtools") -ExtraPaths @($npmPrefix)
$playwrightMcp = Get-ToolCommand -Names @("playwright-mcp") -ExtraPaths @($npmPrefix)
$cdpBrowserMcp = Get-ToolCommand -Names @("cdp-browser-mcp") -ExtraPaths @($npmPrefix)
$publicBrowser = Get-ToolCommand -Names @("public-browser") -ExtraPaths @($npmPrefix)
$vibeSeller = Get-ToolCommand -Names @("vibe-seller") -ExtraPaths @($localBin, $vibeSellerVenvScripts)
$runtimePython = Get-ToolCommand -Names @("python") -ExtraPaths @($runtimeVenvScripts)
$node = Get-ToolCommand -Names @("node")
$npm = Get-ToolCommand -Names @("npm")
$pnpm = Get-ToolCommand -Names @("pnpm")
$uv = Get-ToolCommand -Names @("uv")

$features = @(
  [ordered]@{
    id = "local_ziniao_open"
    name = "Built-in local Ziniao opener"
    available = (Test-Path -LiteralPath (Join-Path $Root "open-store.ps1"))
    mode = "default"
    command = "open-store.ps1"
    notes = "Employee-local store matching, Ziniao launch/login handoff, WebDriver/GUI opening."
  },
  [ordered]@{
    id = "local_python_runtime"
    name = "Local Python runtime for GUI dependencies"
    available = [bool]$runtimePython
    mode = "default_dependency"
    command = $runtimePython
    notes = "Preferred Python for ziniao-ops scripts when installed by install-python-deps.ps1."
  },
  [ordered]@{
    id = "ziniao_cli"
    name = "ziniao CLI / optional MCP route"
    available = [bool]$ziniao
    mode = "optional_external"
    command = $ziniao
    notes = "Use scripts/invoke-ziniao-cli.ps1 when the CLI is installed locally."
  },
  [ordered]@{
    id = "auto_ziniao"
    name = "auto-ziniao flow engine route"
    available = [bool]$autoZiniao
    mode = "optional_external"
    command = $autoZiniao
    notes = "Use scripts/invoke-auto-ziniao.ps1 only when the user explicitly enables the external runner."
  },
  [ordered]@{
    id = "browser_mcp"
    name = "BrowserMCP MCP server route"
    available = [bool]$browserMcp
    mode = "optional_external"
    command = $browserMcp
    notes = "MCP server command is installed when available; actual browser control still requires BrowserMCP Chrome extension and MCP client config."
  },
  [ordered]@{
    id = "chrome_devtools_mcp"
    name = "Chrome DevTools MCP route"
    available = [bool]$chromeDevToolsMcp
    mode = "optional_external"
    command = $chromeDevToolsMcp
    notes = "Official Chrome DevTools MCP. Run scripts/ensure-chrome-devtools-mcp.ps1 -Json when the command is missing; restart Codex after install/PATH changes."
  },
  [ordered]@{
    id = "playwright_mcp"
    name = "Playwright MCP route"
    available = [bool]$playwrightMcp
    mode = "optional_external"
    command = $playwrightMcp
    notes = "Official Playwright MCP. Can use --cdp-endpoint for existing browser sessions; keep optional."
  },
  [ordered]@{
    id = "cdp_browser_mcp"
    name = "Compact CDP Browser MCP route"
    available = [bool]$cdpBrowserMcp
    mode = "optional_external"
    command = $cdpBrowserMcp
    notes = "MIT CDP MCP focused on compact accessibility snapshots."
  },
  [ordered]@{
    id = "public_browser"
    name = "Public Browser direct CDP route"
    available = [bool]$publicBrowser
    mode = "optional_external"
    command = $publicBrowser
    notes = "MIT direct CDP MCP with multi-tab and stable reference ideas."
  },
  [ordered]@{
    id = "vibe_seller"
    name = "Vibe Seller local service route"
    available = [bool]$vibeSeller
    mode = "optional_external"
    command = $vibeSeller
    notes = "Full Vibe Seller is available when installed locally. Do not start the long-running service unless the user explicitly asks and configures required keys."
  },
  [ordered]@{
    id = "auto_ziniao_mirror"
    name = "auto-ziniao reference mirror"
    available = (Test-Path -LiteralPath (Join-Path $Root ".upstreams\WW-AI-Lab__auto-ziniao\.git"))
    mode = "reference_only"
    command = ""
    notes = "License is personal/internal-use. Do not copy code into the public repo without permission."
  },
  [ordered]@{
    id = "vibe_seller_mirror"
    name = "Vibe Seller framework mirror"
    available = (Test-Path -LiteralPath (Join-Path $Root ".upstreams\zpoint__vibe-seller\.git"))
    mode = "reference_mirror"
    command = ""
    notes = "Local mirror for review; this package remains a lightweight Codex skill by default."
  }
)

$report = [ordered]@{
  ok = $true
  root = $Root
  checked_at = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  commands = [ordered]@{
    ziniao = $ziniao
    auto_ziniao = $autoZiniao
    browser_mcp = $browserMcp
    chrome_devtools_mcp = $chromeDevToolsMcp
    playwright_mcp = $playwrightMcp
    cdp_browser_mcp = $cdpBrowserMcp
    public_browser = $publicBrowser
    vibe_seller = $vibeSeller
    node = $node
    npm = $npm
    pnpm = $pnpm
    uv = $uv
  }
  search_paths = [ordered]@{
    local_state_root = $localStateRoot
    python_user_scripts = $pythonScriptDirs
    npm_global_prefix = $npmPrefix
    local_bin = $localBin
    ziniao_cli_venv_scripts = $ziniaoCliVenvScripts
    runtime_venv_scripts = $runtimeVenvScripts
    vibe_seller_venv_scripts = $vibeSellerVenvScripts
    playwright_browsers_path = $playwrightBrowsers
  }
  mirrors = [ordered]@{
    vibe_seller = Test-Mirror "zpoint__vibe-seller"
    auto_ziniao = Test-Mirror "WW-AI-Lab__auto-ziniao"
    browser_mcp = Test-Mirror "BrowserMCP__mcp"
    chrome_devtools_mcp = Test-Mirror "ChromeDevTools__chrome-devtools-mcp"
    playwright_mcp = Test-Mirror "microsoft__playwright-mcp"
    chrome_debug_mcp = Test-Mirror "Rainmen-xia__chrome-debug-mcp"
    cdp_browser_mcp = Test-Mirror "echo-lumen__cdp-browser-mcp"
    public_browser = Test-Mirror "Silbercue__public-browser"
    codex_skills = Test-Mirror "ComposioHQ__awesome-codex-skills"
    openclaw_skills_zh = Test-Mirror "clawdbot-ai__awesome-openclaw-skills-zh"
  }
  features = @($features | ForEach-Object { [pscustomobject]$_ })
}

if ($Json) {
  $report | ConvertTo-Json -Depth 8
} else {
  Write-Host "UPSTREAM_ADAPTER_STATUS"
  foreach ($feature in $features) {
    $state = if ($feature.available) { "available" } else { "not_available" }
    Write-Host ("[{0}] {1} - {2}" -f $state, $feature.id, $feature.notes)
  }
}
