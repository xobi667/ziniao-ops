param(
  [Parameter(Mandatory = $false, Position = 0)]
  [string]$Query,

  [ValidateSet("home", "overview", "orders", "products", "inventory", "ads", "marketing", "business", "traffic", "finance", "chat", "reviews", "vouchers", "campaigns", "livestream", "affiliate", "logistics", "returns", "compass", "dashboard", "discovery", "smax")]
  [string]$View = "home",

  [ValidateSet("", "shopee", "tiktok", "lazada")]
  [string]$Platform = "",

  [string]$ShopsPath = "",

  [switch]$NavigateView,
  [switch]$UrlOnly,
  [switch]$UrlFallback,
  [switch]$AllowHomeFallback,
  [switch]$AllowCommand,
  [switch]$CurrentWindowFirst,

  [int]$LoginTimeoutSeconds = 180,
  [switch]$RefreshZiniao,
  [switch]$DryRun,
  [switch]$List,
  [switch]$Json
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
if (!$ShopsPath) {
  $ShopsPath = Join-Path $root "shops.json"
}
$ViewWasInferred = $false

function Write-Result($obj, [int]$Code = 0) {
  if ($Json) {
    $obj | ConvertTo-Json -Depth 10
  } else {
    if ($obj.message) { Write-Host $obj.message }
    if ($obj.candidates) {
      foreach ($item in $obj.candidates) {
        Write-Host ("- {0} / {1} score={2}" -f $item.platform, $item.name, $item.score)
      }
    }
  }
  exit $Code
}

function Get-PythonCommand {
  $configPath = Join-Path $root "ziniao.local.json"
  if (Test-Path -LiteralPath $configPath) {
    try {
      $cfg = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
      if ($cfg.python_path) {
        $pythonPath = [Environment]::ExpandEnvironmentVariables([string]$cfg.python_path)
        if (Test-Path -LiteralPath $pythonPath -PathType Leaf) { return @($pythonPath) }
      }
      if ($cfg.local_state_root) {
        $venvPython = Join-Path ([Environment]::ExpandEnvironmentVariables([string]$cfg.local_state_root)) "tools\python-venv\Scripts\python.exe"
        if (Test-Path -LiteralPath $venvPython -PathType Leaf) { return @($venvPython) }
      }
    } catch {
    }
  }
  $defaultVenvPython = Join-Path $root ".ziniao-ops\tools\python-venv\Scripts\python.exe"
  if (Test-Path -LiteralPath $defaultVenvPython -PathType Leaf) { return @($defaultVenvPython) }
  if (Get-Command python -ErrorAction SilentlyContinue) { return @("python") }
  if (Get-Command py -ErrorAction SilentlyContinue) { return @("py", "-3") }
  return @()
}

function Invoke-PythonFile {
  param(
    [string]$ScriptPath,
    [string[]]$ScriptArgs
  )
  [array]$python = @(Get-PythonCommand)
  if ($python.Count -eq 0) {
    Write-Result @{
      ok = $false
      error = "python_missing"
      message = "Python was not found on this computer. Install Python 3, or make sure python/py is available in PATH."
    } 3
  }
  $pythonExe = $python[0]
  $pythonArgs = @()
  if ($python.Count -gt 1) { $pythonArgs = @($python[1..($python.Count - 1)]) }
  & $pythonExe @pythonArgs $ScriptPath @ScriptArgs
  return $LASTEXITCODE
}

function Invoke-PythonFilePassthru {
  param(
    [string]$ScriptPath,
    [string[]]$ScriptArgs
  )
  [array]$python = @(Get-PythonCommand)
  if ($python.Count -eq 0) {
    Write-Result @{
      ok = $false
      error = "python_missing"
      message = "Python was not found on this computer. Install Python 3, or make sure python/py is available in PATH."
    } 3
  }
  $pythonExe = $python[0]
  $pythonArgs = @()
  if ($python.Count -gt 1) { $pythonArgs = @($python[1..($python.Count - 1)]) }
  & $pythonExe @pythonArgs $ScriptPath @ScriptArgs
  $script:LastPythonExitCode = $LASTEXITCODE
}

function Invoke-ZiniaoGuiFallback {
  param(
    [string]$ShopName,
    [string]$ZiniaoName = "",
    [string[]]$Aliases = @(),
    [int]$TimeoutSeconds = $LoginTimeoutSeconds,
    [switch]$NoLaunch,
    [switch]$ContinueOnFailure
  )
  $script = Join-Path $root "scripts\ziniao-gui-open.py"
  if (!(Test-Path -LiteralPath $script)) {
    $missingPayload = @{
      ok = $false
      error = "ziniao_gui_script_missing"
      message = "紫鸟 GUI 兜底脚本不存在: $script"
    }
    if ($ContinueOnFailure) {
      return [pscustomobject]@{ Code = 1; Output = @(); Payload = $missingPayload }
    }
    Write-Result $missingPayload 1
  }
  $argsList = @(
    "--shop-name", $ShopName,
    "--query", $Query,
    "--view", $View,
    "--ziniao-name", $ZiniaoName,
    "--login-timeout", ([string]$TimeoutSeconds),
    "--json"
  )
  if ($NoLaunch) { $argsList += "--no-launch" }
  if ($NoLaunch -and $ContinueOnFailure) { $argsList += @("--fast-visible-click", "--quick-only") }
  foreach ($alias in @($Aliases)) {
    if ($alias) {
      $argsList += @("--alias", [string]$alias)
    }
  }
  [array]$python = @(Get-PythonCommand)
  if ($python.Count -eq 0) {
    $payload = @{
      ok = $false
      error = "python_missing"
      message = "Python was not found on this computer. Install Python 3, or make sure python/py is available in PATH."
    }
    if ($ContinueOnFailure) {
      return [pscustomobject]@{ Code = 3; Output = @(); Payload = $payload }
    }
    Write-Result $payload 3
  }
  $pythonExe = $python[0]
  $pythonArgs = @()
  if ($python.Count -gt 1) { $pythonArgs = @($python[1..($python.Count - 1)]) }
  $output = @(& $pythonExe @pythonArgs $script @argsList 2>&1)
  $code = $LASTEXITCODE
  if ($ContinueOnFailure) {
    return [pscustomobject]@{ Code = $code; Output = $output; Payload = $null }
  }
  $output | ForEach-Object { Write-Output $_ }
  exit $code
}

function Invoke-ZiniaoShopSync {
  $script = Join-Path $root "scripts\sync-ziniao-shops.py"
  if (!(Test-Path -LiteralPath $script)) {
    Write-Result @{
      ok = $false
      error = "sync_script_missing"
      message = "本机紫鸟店铺扫描脚本不存在: $script"
    } 1
  }

  [array]$python = @(Get-PythonCommand)
  if ($python.Count -eq 0) {
    Write-Result @{
      ok = $false
      error = "python_missing"
      message = "Python was not found on this computer. Install Python 3, or make sure python/py is available in PATH."
    } 3
  }

  $pythonExe = $python[0]
  $pythonArgs = @()
  if ($python.Count -gt 1) { $pythonArgs = @($python[1..($python.Count - 1)]) }
  $syncTimeoutSeconds = [Math]::Min(25, [Math]::Max(4, $LoginTimeoutSeconds))
  $syncArgs = @($script, "--out", $ShopsPath, "--json", "--timeout", ([string]$syncTimeoutSeconds), "--login-timeout", ([string]$LoginTimeoutSeconds))
  $output = @(& $pythonExe @pythonArgs @syncArgs 2>&1)
  $code = $LASTEXITCODE
  if ($code -ne 0) {
    if (!$DryRun -and !$List -and $Query -and !$UrlOnly -and !$NavigateView) {
      Invoke-ZiniaoGuiFallback -ShopName $Query -ZiniaoName $Query -Aliases @($Query)
    }
    if ($output.Count -gt 0) {
      $output | ForEach-Object { Write-Output $_ }
    } else {
      Write-Result @{
        ok = $false
        error = "ziniao_sync_failed"
        message = "本机紫鸟店铺扫描失败。请先打开并登录紫鸟。"
      } $code
    }
    exit $code
  }
}

function Test-ShopsNeedSync([string]$Path) {
  if (!(Test-Path -LiteralPath $Path)) { return $true }
  try {
    $existing = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    return (@($existing.shops).Count -le 0)
  } catch {
    return $true
  }
}

function Quote-Arg([string]$Text) {
  if ($null -eq $Text) { return '""' }
  return '"' + ($Text -replace '"', '\"') + '"'
}

function Quote-PowerShellLiteral([string]$Text) {
  if ($null -eq $Text) { return "''" }
  return "'" + ($Text -replace "'", "''") + "'"
}

function Normalize-Text([string]$Text) {
  $value = ""
  if ($null -ne $Text) {
    $value = $Text.Trim().ToLowerInvariant()
  }
  $value = $value -replace "\u3000", " "
  $value = $value -replace "\s+", " "
  foreach ($suffix in @(" 自营", "自营", "-自营", " 自營", "自營", " 合作", "合作", "-合作")) {
    if ($value.EndsWith($suffix)) {
      $value = $value.Substring(0, $value.Length - $suffix.Length).Trim()
      break
    }
  }
  return ($value -replace "[\s._-]+", "")
}

function Resolve-ViewFromQuery([string]$Text) {
  if (!$Text) { return "home" }
  $value = " $Text "
  $rules = @(
    @("returns", "退货退款|退款退货|售后|退款|退货|return|refund|after\s*sale|after-sale"),
    @("logistics", "物流|发货|履约|配送|运单|面单|shipping|shipment|logistics|fulfillment"),
    @("orders", "订单|出单|未发货|待发货|order|orders"),
    @("products", "商品|产品|刊登|listing|listings|product|products|sku"),
    @("inventory", "库存|仓库|仓储|stock|inventory|warehouse"),
    @("ads", "广告页|广告后台|广告数据|投流|投放|ads|advertis|sponsored"),
    @("smax", "全效宝|全站推广|max\s*全站推广|smax|smart\s*max"),
    @("discovery", "discovery|推广发现|发现页"),
    @("compass", "compass|罗盘|数据罗盘"),
    @("business", "数据中心|商业分析|生意参谋|经营分析|运营数据|business\s*insights?|business\s*analytics?|analytics"),
    @("dashboard", "dashboard|看板|仪表盘|数据看板"),
    @("traffic", "流量|访客|访问|转化|traffic|visitor|visitors|conversion"),
    @("finance", "财务|钱包|结算|账单|回款|收款|余额|finance|wallet|settlement|payout|billing"),
    @("chat", "客服|聊天|消息|私信|会话|chat|message|messages|inbox|im"),
    @("reviews", "评价|评论|星级|差评|review|reviews|rating|ratings|comment|comments"),
    @("vouchers", "优惠券|折扣券|coupon|coupons|voucher|vouchers"),
    @("campaigns", "活动|报名|大促|campaign|campaigns|promotion|promotions"),
    @("livestream", "直播|live\s*stream|livestream|live"),
    @("affiliate", "联盟|达人|分销|affiliate|creator|influencer"),
    @("marketing", "营销中心|营销|marketing|promotion\s*center"),
    @("overview", "全部数据|全部情况|整体情况|总览|概览|概况|overview|summary")
  )
  foreach ($rule in $rules) {
    if ($value -match $rule[1]) { return $rule[0] }
  }
  return "home"
}

function Get-QueryVariants([string]$Text) {
  $items = New-Object System.Collections.Generic.List[string]
  if ($Text) { $items.Add($Text) }

  $clean = " $Text "
  foreach ($pattern in @(
    "打开|开一下|开下|进入|进去|帮我看|看一下|看下|看看|帮忙看|麻烦看",
    "店铺后台|店铺|后台",
    "全部数据|全部情况|整体情况|总览|概览|概况",
    "订单数据|订单管理|订单|出单|未发货|待发货",
    "商品数据|商品管理|商品|产品|刊登|sku",
    "库存数据|库存|仓库|仓储",
    "广告页|广告后台|广告数据|投流后台|投流|投放|广告",
    "营销中心|营销数据|营销|优惠券|折扣券|活动报名|活动|大促",
    "数据中心|商业分析|生意参谋|经营分析|运营数据|流量数据|流量|访客|转化",
    "财务数据|财务|钱包|结算|账单|回款|收款|余额",
    "客服数据|客服|聊天|消息|私信|会话",
    "评价数据|评价|评论|星级|差评",
    "直播数据|直播|联盟数据|联盟|达人|分销",
    "物流|发货|履约|配送|运单|面单|售后|退款|退货",
    "compass|罗盘|数据罗盘|dashboard|discovery|smax|全效宝|max\s*全站推广",
    "seller\s*center|asc",
    "页面|弹窗|广告弹窗|教程弹窗|公告|挡住了|跳过",
    "\bhome\b|\boverview\b|\borders?\b|\bproducts?\b|\binventory\b|\bads\b|\bbusiness\b|\bmarketing\b|\btraffic\b|\bfinance\b|\bchat\b|\breviews?\b|\bvouchers?\b|\bcampaigns?\b|\blivestream\b|\baffiliate\b|\blogistics\b|\breturns?\b",
    "帮忙|麻烦"
  )) {
    $clean = [regex]::Replace($clean, $pattern, " ", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  }
  $clean = $clean -replace "[，,。:：；;（）()【】\[\]""'“”]", " "
  $clean = ($clean -replace "\s+", " ").Trim()
  if ($clean -and $clean -ne $Text.Trim()) {
    $items.Add($clean)
  }
  $particleClean = [regex]::Replace(" $clean ", "的|被|了|啦", " ", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  $particleClean = ($particleClean -replace "\s+", " ").Trim()
  if ($particleClean -and $particleClean -ne $clean -and $particleClean -ne $Text.Trim()) {
    $items.Add($particleClean)
  }

  return @($items | Select-Object -Unique)
}

function Get-Texts($Shop) {
  $items = New-Object System.Collections.Generic.List[string]
  if ($Shop.name) { $items.Add([string]$Shop.name) }
  foreach ($alias in @($Shop.aliases)) {
    if ($alias) { $items.Add([string]$alias) }
  }
  return $items
}

function Score-Shop([string]$Needle, $Shop) {
  $best = 0
  foreach ($variant in (Get-QueryVariants $Needle)) {
    $q = Normalize-Text $variant
    if (!$q) { continue }
    foreach ($text in (Get-Texts $Shop)) {
      $t = Normalize-Text $text
      if (!$t) { continue }
      if ($t -eq $q) { $best = [Math]::Max($best, 110); continue }
      if ($t.Contains($q)) { $best = [Math]::Max($best, [Math]::Min(99, 82 + [Math]::Min(17, $q.Length))) }
      if ($q.Contains($t) -and $t.Length -ge 3) { $best = [Math]::Max($best, 80) }
      $tokens = @($variant.ToLowerInvariant() -split "[\s._-]+" | Where-Object { $_ })
      if ($tokens.Count -gt 0) {
        $all = $true
        foreach ($token in $tokens) {
          if (!($text.ToLowerInvariant().Contains($token) -or $t.Contains($token))) {
            $all = $false
            break
          }
        }
        if ($all) { $best = [Math]::Max($best, 95) }
      }
    }
  }
  return $best
}

if (!$PSBoundParameters.ContainsKey("View")) {
  $inferred = Resolve-ViewFromQuery $Query
  if ($inferred -and $inferred -ne "home") {
    $View = $inferred
    $ViewWasInferred = $true
  }
}

if ($CurrentWindowFirst -and !$DryRun -and !$List -and $Query -and !$UrlOnly -and !$NavigateView) {
  $quickGui = Invoke-ZiniaoGuiFallback -ShopName $Query -ZiniaoName $Query -Aliases @($Query) -TimeoutSeconds 0 -NoLaunch -ContinueOnFailure
  if ($quickGui.Code -eq 0) {
    $quickGui.Output | ForEach-Object { Write-Output $_ }
    exit 0
  }
}

if ($RefreshZiniao -or (Test-ShopsNeedSync $ShopsPath)) {
  Invoke-ZiniaoShopSync
}

if (!(Test-Path -LiteralPath $ShopsPath)) {
  Write-Result @{
    ok = $false
    error = "shops_json_missing_after_sync"
    message = "shops.json not found and automatic Ziniao sync did not create it: $ShopsPath"
  } 1
}

$data = Get-Content -LiteralPath $ShopsPath -Raw -Encoding UTF8 | ConvertFrom-Json
$shops = @($data.shops)

if ($List) {
  $rows = $shops | ForEach-Object {
    [pscustomobject]@{ platform = $_.platform; name = $_.name; country = $_.country }
  }
  Write-Result @{ ok = $true; shops = $rows; message = "shops: $($rows.Count)" } 0
}

if (!$Query) {
  Write-Result @{ ok = $false; message = "Missing query. Example: .\open-shop.ps1 `"<店铺关键词>`" -View ads" } 1
}

$matches = New-Object System.Collections.Generic.List[object]
foreach ($shop in $shops) {
  if ($Platform -and ([string]$shop.platform).ToLowerInvariant() -ne $Platform) { continue }
  $score = Score-Shop $Query $shop
  if ($score -ge 55) {
    $matches.Add([pscustomobject]@{
      platform = $shop.platform
      name = $shop.name
      country = $shop.country
      score = $score
      shop = $shop
    })
  }
}

$ordered = @($matches | Sort-Object @{ Expression = "score"; Descending = $true }, platform, name)
if ($ordered.Count -eq 0) {
  if (!$DryRun -and !$List -and $Query -and !$UrlOnly -and !$NavigateView) {
    Invoke-ZiniaoGuiFallback -ShopName $Query -ZiniaoName $Query -Aliases @($Query)
  }
  Write-Result @{ ok = $false; message = "No local shop matched: $Query" } 1
}

$top = $ordered[0]
$secondScore = if ($ordered.Count -gt 1) { [int]$ordered[1].score } else { -1 }
$queryCompact = Normalize-Text $Query
if ($ordered.Count -gt 1 -and (($queryCompact.Length -le 6) -or (([int]$top.score - $secondScore) -lt 12))) {
  $candidates = @($ordered | Select-Object -First 8 | ForEach-Object {
    [pscustomobject]@{ platform = $_.platform; name = $_.name; country = $_.country; score = $_.score }
  })
  Write-Result @{ ok = $false; error = "multiple_matches"; message = "Multiple shops matched. Add platform/country/more keywords."; candidates = $candidates } 2
}

$shop = $top.shop
$autoDetectedShop = ([string]$data.source -eq "ziniao_detected") -or ([string]$shop.detected_from -eq "ziniao_webdriver")
$shopDefaultMethod = if ($UrlOnly) { "url" } elseif ($shop.open_method) { [string]$shop.open_method } elseif ($shop.platform -in @("shopee", "tiktok", "unknown")) { "ziniao_webdriver" } elseif ($shop.platform -eq "lazada") { "ziniao_gui" } else { "url" }
$views = $shop.views
$target = $null
$actualView = $View
$visualNavigationRequired = $false
if ($views -and $views.PSObject.Properties.Name -contains $View) {
  $target = $views.$View
} elseif ($View -ne "home" -and $AllowHomeFallback -and $views -and $views.PSObject.Properties.Name -contains "home") {
  $target = $views.home
  $actualView = "home"
}

if (!$target) {
  if ($autoDetectedShop -and !$UrlOnly -and !$NavigateView -and ($shopDefaultMethod -in @("ziniao_webdriver", "ziniao_gui"))) {
    $target = [pscustomobject]@{ url = ""; visual_hint = $true }
    $visualNavigationRequired = $true
  } else {
    $availableViews = @()
    if ($views) { $availableViews = @($views.PSObject.Properties.Name) }
    Write-Result @{
      ok = $false
      error = "view_url_missing"
      message = "Matched shop but requested view is not configured: $View. Add this view URL to shops.json, or rerun with -AllowHomeFallback if opening home is acceptable."
      matched = @{ platform = $shop.platform; name = $shop.name }
      requested_view = $View
      available_views = $availableViews
    } 1
  }
}

$url = if ($target -is [string]) { $target } else { [string]$target.url }
$command = if ($UrlOnly) { "" } elseif ($target -isnot [string] -and $target.command) { [string]$target.command } elseif ($shop.open_command) { [string]$shop.open_command } else { "" }
$method = if ($UrlOnly) { "url" } elseif ($command) { "command" } elseif ($target -isnot [string] -and $target.open_method) { [string]$target.open_method } else { $shopDefaultMethod }
if ([string]::IsNullOrWhiteSpace($url) -and !($autoDetectedShop -and !$UrlOnly -and !$NavigateView -and ($method -in @("ziniao_webdriver", "ziniao_gui")))) {
  Write-Result @{
    ok = $false
    error = "view_url_missing"
    message = "Matched shop but requested view URL is empty: $actualView. Add this view URL to shops.json."
    matched = @{ platform = $shop.platform; name = $shop.name }
    requested_view = $View
    actual_view = $actualView
  } 1
}
if ([string]::IsNullOrWhiteSpace($url)) {
  $visualNavigationRequired = $true
}
$navigationUrl = if ($NavigateView) { $url } else { "" }
$ziniaoName = if ($shop.ziniao_name) { [string]$shop.ziniao_name } else { [string]$shop.name }
$browserOauth = if ($shop.browser_oauth) { [string]$shop.browser_oauth } else { "" }
$browserId = if ($shop.browser_id) { [string]$shop.browser_id } else { "" }
$allowUrlFallback = [bool]$UrlFallback -or [bool]$shop.allow_url_fallback

$payload = @{
  ok = $true
  message = "已匹配: $($shop.platform) / $($shop.name) view=$actualView method=$method。默认只打开本机店铺环境；后续页面点击交给 Codex 视觉操作。能否进入后台取决于这台电脑是否已登录该店铺账号。"
  matched = @{
    platform = $shop.platform
    name = $shop.name
    country = $shop.country
    view = $actualView
    requested_view = $View
    actual_view = $actualView
    view_inferred_from_query = $ViewWasInferred
    fallback_to_home = ($actualView -ne $View)
    url = $url
    navigate_view = [bool]$NavigateView
    needs_visual_navigation = [bool]$visualNavigationRequired
    open_method = $method
    ziniao_name = $ziniaoName
  }
  login_policy = @{
    requires_local_login = $true
    auto_login = $false
    bypass_login = $false
    credential_storage = $false
    if_login_page = "如果页面跳到登录页，停止操作；员工必须在这台电脑手动登录，然后重新执行同一条命令。"
  }
  dry_run = [bool]$DryRun
}

if ($command -and !$AllowCommand) {
  Write-Result @{
    ok = $false
    error = "command_disabled"
    message = "Matched shop uses open_command/target command, but local command execution is disabled by default. Only rerun with -AllowCommand if this shops.json is trusted."
    matched = $payload.matched
  } 1
}

if ($DryRun) {
  Write-Result $payload 0
}

function Invoke-UrlOpen {
  param([string]$TargetUrl)
  if (!$TargetUrl) {
    Write-Result @{ ok = $false; message = "Matched shop but URL is empty for view: $View"; matched = $payload.matched } 1
  }
  Start-Process $TargetUrl
  if (!$Json) {
    Write-Host "已打开本机链接。若页面是登录页，说明这台电脑尚未登录该店铺。"
    Write-Host "请员工在本机手动登录后重试；脚本不会自动登录，也不会绕过验证码或安全验证。"
  }
  Write-Result $payload 0
}

function Invoke-PythonScript {
  param(
    [string]$ScriptPath,
    [string[]]$ScriptArgs
  )
  [array]$python = @(Get-PythonCommand)
  if ($python.Count -gt 0) {
    $pythonExe = $python[0]
    $pythonArgs = @()
    if ($python.Count -gt 1) { $pythonArgs = @($python[1..($python.Count - 1)]) }
    & $pythonExe @pythonArgs $ScriptPath @ScriptArgs
    return $LASTEXITCODE
  }
  Write-Result @{
    ok = $false
    error = "python_missing"
    message = "Python was not found on this computer. Install Python 3, or make sure python/py is available in PATH."
  } 3
}

if ($command) {
  $commandPlaceholders = @{
    "{url}" = Quote-PowerShellLiteral $url
    "{name}" = Quote-PowerShellLiteral ([string]$shop.name)
    "{platform}" = Quote-PowerShellLiteral ([string]$shop.platform)
    "{view}" = Quote-PowerShellLiteral $actualView
  }
  $safeCommand = [regex]::Replace($command, "\{url\}|\{name\}|\{platform\}|\{view\}", {
    param($match)
    $commandPlaceholders[$match.Value]
  })
  powershell -NoProfile -ExecutionPolicy Bypass -Command $safeCommand
  exit $LASTEXITCODE
}

if ($method -eq "ziniao_webdriver") {
  $script = Join-Path $root "scripts\ziniao-webdriver-open.py"
  $argsList = @(
    "--shop-name", [string]$shop.name,
    "--platform", [string]$shop.platform,
    "--view", $actualView,
    "--url", $navigationUrl,
    "--ziniao-name", $ziniaoName,
    "--browser-oauth", $browserOauth,
    "--browser-id", $browserId,
    "--login-timeout", ([string]$LoginTimeoutSeconds),
    "--json"
  )
  foreach ($alias in @($shop.aliases)) {
    if ($alias) {
      $argsList += @("--alias", [string]$alias)
    }
  }
  $code = Invoke-PythonScript $script $argsList
  if ($code -eq 0) { exit 0 }
  if (!$UrlOnly -and !$NavigateView) {
    Invoke-ZiniaoGuiFallback -ShopName ([string]$shop.name) -ZiniaoName $ziniaoName -Aliases @($shop.aliases)
  }
  if ($allowUrlFallback) {
    Write-Host "精准打开失败，按 UrlFallback 退回普通链接打开。"
    Invoke-UrlOpen $url
  }
  exit $code
}

if ($method -eq "ziniao_gui") {
  $script = Join-Path $root "scripts\lazada-gui-open.py"
  $argsList = @(
    "--shop-name", [string]$shop.name,
    "--view", $actualView,
    "--url", $navigationUrl,
    "--ziniao-name", $ziniaoName,
    "--json"
  )
  foreach ($alias in @($shop.aliases)) {
    if ($alias) {
      $argsList += @("--alias", [string]$alias)
    }
  }
  $code = Invoke-PythonScript $script $argsList
  if ($code -eq 0) { exit 0 }
  if ($allowUrlFallback) {
    Write-Host "精准打开失败，按 UrlFallback 退回普通链接打开。"
    Invoke-UrlOpen $url
  }
  exit $code
}

Invoke-UrlOpen $url
