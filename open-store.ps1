param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$Query,

  [ValidateSet("home", "overview", "orders", "products", "inventory", "ads", "marketing", "business", "traffic", "finance", "chat", "reviews", "vouchers", "campaigns", "livestream", "affiliate", "logistics", "returns", "compass", "dashboard", "discovery", "smax")]
  [string]$View = "home",

  [ValidateSet("", "shopee", "tiktok", "lazada")]
  [string]$Platform = "",

  [int]$LoginTimeoutSeconds = 1800,
  [int]$FastOpenTimeoutSeconds = 15,

  [switch]$NavigateView,
  [switch]$UrlFallback,
  [switch]$AllowHomeFallback,
  [switch]$DryRun,
  [switch]$Json
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath $PSScriptRoot).Path
$ViewWasInferred = $false

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

if (!$PSBoundParameters.ContainsKey("View")) {
  $inferred = Resolve-ViewFromQuery $Query
  if ($inferred -and $inferred -ne "home") {
    $View = $inferred
    $ViewWasInferred = $true
  }
}

function ConvertFrom-JsonOutput($Lines) {
  $text = (($Lines | Out-String).Trim())
  if (!$text) { return $null }
  try {
    return $text | ConvertFrom-Json
  } catch {
    return $null
  }
}

function Write-OneShotResult($Payload, [int]$Code = 0) {
  if ($Json) {
    $Payload | ConvertTo-Json -Depth 12
  } else {
    if ($Payload.message) { Write-Host $Payload.message }
    if ($Payload.error) { Write-Host ("error: {0}" -f $Payload.error) }
    if ($Payload.next_step) { Write-Host ("next: {0}" -f $Payload.next_step) }
  }
  exit $Code
}

$setupScript = Join-Path $root "setup-ziniao.ps1"
$openScript = Join-Path $root "open-shop.ps1"
if (!(Test-Path -LiteralPath $setupScript)) {
  Write-OneShotResult ([ordered]@{
    ok = $false
    method = "open_store_after_login"
    error = "setup_ziniao_missing"
    message = "setup-ziniao.ps1 is missing."
  }) 1
}
if (!(Test-Path -LiteralPath $openScript)) {
  Write-OneShotResult ([ordered]@{
    ok = $false
    method = "open_store_after_login"
    error = "open_shop_missing"
    message = "open-shop.ps1 is missing."
  }) 1
}

function Invoke-OpenShopCommand([int]$TimeoutSeconds, [switch]$CurrentWindowFirst) {
  $openArgs = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", $openScript,
    $Query,
    "-View", $View,
    "-LoginTimeoutSeconds", ([string]$TimeoutSeconds),
    "-Json"
  )
  if ($Platform) { $openArgs += @("-Platform", $Platform) }
  if ($NavigateView) { $openArgs += "-NavigateView" }
  if ($UrlFallback) { $openArgs += "-UrlFallback" }
  if ($AllowHomeFallback) { $openArgs += "-AllowHomeFallback" }
  if ($DryRun) { $openArgs += "-DryRun" }
  if ($CurrentWindowFirst) { $openArgs += "-CurrentWindowFirst" }

  $output = @(& powershell @openArgs 2>&1)
  $code = $LASTEXITCODE
  [pscustomobject]@{
    Code = $code
    Json = ConvertFrom-JsonOutput $output
    Output = $output
  }
}

function Test-SetupCannotFixOpenFailure($OpenJson) {
  if (!$OpenJson) { return $false }
  $error = [string]$OpenJson.error
  if (!$error -and $OpenJson.open) { $error = [string]$OpenJson.open.error }
  return ($error -in @(
    "multiple_matches",
    "view_url_missing",
    "shops_cache_missing",
    "shops_cache_empty",
    "command_disabled",
    "python_missing",
    "pywinauto_missing",
    "non_windows"
  ))
}

if (!$Json) {
  Write-Host "Trying the current Ziniao window or already-open store first."
}

$fastTimeout = [Math]::Max(0, [Math]::Min($FastOpenTimeoutSeconds, $LoginTimeoutSeconds))
$fastOpen = Invoke-OpenShopCommand -TimeoutSeconds $fastTimeout -CurrentWindowFirst
if ($fastOpen.Code -eq 0) {
  if ($Json) {
    Write-OneShotResult ([ordered]@{
      ok = $true
      method = "open_store_fast_path"
      query = $Query
      view = $View
      view_inferred_from_query = $ViewWasInferred
      current_window_first = $true
      open = $fastOpen.Json
      raw_open_output = if ($fastOpen.Json) { $null } else { $fastOpen.Output }
    }) 0
  }
  if ($fastOpen.Json -and $fastOpen.Json.message) {
    Write-Host $fastOpen.Json.message
  } else {
    $fastOpen.Output | ForEach-Object { Write-Output $_ }
  }
  exit 0
}

if ($DryRun) {
  if ($Json) {
    Write-OneShotResult ([ordered]@{
      ok = $false
      method = "open_store_dry_run"
      query = $Query
      view = $View
      view_inferred_from_query = $ViewWasInferred
      current_window_first = $true
      open = $fastOpen.Json
      raw_open_output = if ($fastOpen.Json) { $null } else { $fastOpen.Output }
    }) $fastOpen.Code
  }
  if ($fastOpen.Json -and $fastOpen.Json.message) {
    Write-Host $fastOpen.Json.message
  } else {
    $fastOpen.Output | ForEach-Object { Write-Output $_ }
  }
  exit $fastOpen.Code
}

if (Test-SetupCannotFixOpenFailure $fastOpen.Json) {
  if ($Json) {
    Write-OneShotResult ([ordered]@{
      ok = $false
      method = "open_store_fast_path"
      query = $Query
      view = $View
      view_inferred_from_query = $ViewWasInferred
      current_window_first = $true
      open = $fastOpen.Json
      raw_open_output = if ($fastOpen.Json) { $null } else { $fastOpen.Output }
    }) $fastOpen.Code
  }
  if ($fastOpen.Json -and $fastOpen.Json.message) {
    Write-Host $fastOpen.Json.message
  } else {
    $fastOpen.Output | ForEach-Object { Write-Output $_ }
  }
  exit $fastOpen.Code
}

if (!$Json) {
  Write-Host "Current-window quick open did not finish. Preparing Ziniao and waiting for local login if needed."
  Write-Host "Complete login in the Ziniao window; this command will continue automatically after login."
}

$setupArgs = @(
  "-NoProfile",
  "-ExecutionPolicy", "Bypass",
  "-File", $setupScript,
  "-LoginTimeoutSeconds", ([string]$LoginTimeoutSeconds),
  "-Json"
)
$setupOutput = @(& powershell @setupArgs 2>&1)
$setupCode = $LASTEXITCODE
$setupJson = ConvertFrom-JsonOutput $setupOutput
$setupWarning = $null
if ($setupCode -ne 0) {
  $message = if ($setupJson -and $setupJson.message) {
    [string]$setupJson.message
  } else {
    "Ziniao setup did not finish."
  }
  $setupError = if ($setupJson -and $setupJson.error) { [string]$setupJson.error } else { "ziniao_setup_failed" }
  if ($setupError -in @("ziniao_shop_sync_failed", "ziniao_browser_list_empty", "ziniao_no_usable_shops")) {
    $setupWarning = [ordered]@{
      error = $setupError
      message = $message
      action = "continue_to_open_shop_gui_fallback"
    }
    if (!$Json) {
      Write-Warning "$message Continuing to store open flow and GUI fallback."
    }
  } else {
    Write-OneShotResult ([ordered]@{
      ok = $false
      method = "open_store_after_login"
      error = $setupError
      message = $message
      query = $Query
      view = $View
      view_inferred_from_query = $ViewWasInferred
      setup = $setupJson
      raw_output = if ($setupJson) { $null } else { $setupOutput }
      next_step = "Finish login in the foregrounded Ziniao window, then run the same open command again."
    }) $setupCode
  }
}

if (!$Json) {
  Write-Host "Ziniao is ready. Opening the requested store..."
}

$openResult = Invoke-OpenShopCommand -TimeoutSeconds 180
$openOutput = $openResult.Output
$openCode = $openResult.Code
if ($Json) {
  Write-OneShotResult ([ordered]@{
    ok = ($openCode -eq 0 -and $openResult.Json -and [bool]$openResult.Json.ok)
    method = "open_store_after_login"
    query = $Query
    view = $View
    view_inferred_from_query = $ViewWasInferred
    fast_open = $fastOpen.Json
    raw_fast_open_output = if ($fastOpen.Json) { $null } else { $fastOpen.Output }
    setup = $setupJson
    setup_warning = $setupWarning
    open = $openResult.Json
    raw_open_output = if ($openResult.Json) { $null } else { $openOutput }
  }) $openCode
}

if ($openResult.Json -and $openResult.Json.message) {
  Write-Host $openResult.Json.message
} else {
  $openOutput | ForEach-Object { Write-Output $_ }
}
exit $openCode
