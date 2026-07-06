param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$CsvPath,

  [string]$OutPath = ""
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
if (!$OutPath) {
  $OutPath = Join-Path $root "shops.json"
}

function Get-Field($Row, [string[]]$Names) {
  foreach ($name in $Names) {
    if ($Row.PSObject.Properties.Name -contains $name) {
      $value = [string]$Row.$name
      if ($value.Trim()) { return $value.Trim() }
    }
  }
  return ""
}

function Split-Aliases([string]$Text) {
  if (!$Text) { return @() }
  return @($Text -split "[,，;；\n]+" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

if (!(Test-Path $CsvPath)) {
  throw "CSV not found: $CsvPath"
}

function Import-CsvAutoEncoding([string]$Path) {
  $resolved = (Resolve-Path -LiteralPath $Path).Path
  $bytes = [System.IO.File]::ReadAllBytes($resolved)
  if ($bytes.Length -eq 0) { return @() }

  $encodings = New-Object System.Collections.Generic.List[System.Text.Encoding]
  if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    $encodings.Add((New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $true, $true))
  } else {
    $encodings.Add((New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $false, $true))
  }
  $encodings.Add([System.Text.Encoding]::Default)

  $lastError = $null
  foreach ($encoding in $encodings) {
    try {
      $text = $encoding.GetString($bytes)
      if ($text.Length -gt 0 -and $text[0] -eq [char]0xFEFF) {
        $text = $text.Substring(1)
      }
      $lines = @($text -split "`r?`n" | Where-Object { $_ -ne "" })
      if ($lines.Count -eq 0) { return @() }
      return @(ConvertFrom-Csv -InputObject $lines)
    } catch {
      $lastError = $_.Exception
    }
  }
  throw "Failed to read CSV as UTF-8 or system default encoding: $($lastError.Message)"
}

$rows = Import-CsvAutoEncoding $CsvPath
$shops = @()

foreach ($row in $rows) {
  $name = Get-Field $row @("name", "shop_name", "店铺", "店铺名称", "店铺名")
  $platform = (Get-Field $row @("platform", "平台")).ToLowerInvariant()
  if (!$name -or !$platform) { continue }

  $country = (Get-Field $row @("country", "国家", "站点")).ToLowerInvariant()
  $aliases = Split-Aliases (Get-Field $row @("aliases", "alias", "别名", "关键词"))
  $ziniaoName = Get-Field $row @("ziniao_name", "紫鸟店铺名", "紫鸟名称", "紫鸟别名")
  if (!$ziniaoName) { $ziniaoName = $name }
  $browserOauth = Get-Field $row @("browser_oauth", "browserOauth", "紫鸟OAuth", "紫鸟店铺ID")
  $browserId = Get-Field $row @("browser_id", "browserId", "紫鸟浏览器ID")
  $openMethod = (Get-Field $row @("open_method", "打开方式")).ToLowerInvariant()
  if (!$openMethod) {
    if ($platform -in @("shopee", "tiktok")) {
      $openMethod = "ziniao_webdriver"
    } elseif ($platform -eq "lazada") {
      $openMethod = "ziniao_gui"
    } else {
      $openMethod = "url"
    }
  }
  if ($aliases -notcontains $name) {
    $aliases = @($aliases)
  }

  $views = [ordered]@{}
  $viewMap = @{
    home = @("home_url", "homeUrl", "homeURL", "HomeURL", "首页链接", "主页链接", "首页URL", "主页URL")
    overview = @("overview_url", "overviewUrl", "overviewURL", "OverviewURL", "summary_url", "SummaryURL", "总览链接", "概览链接", "概况链接", "店铺总览链接", "总览URL", "概览URL", "概况URL", "店铺总览URL")
    orders = @("orders_url", "ordersUrl", "ordersURL", "OrdersURL", "order_url", "OrderURL", "订单链接", "订单页链接", "订单管理链接", "订单URL", "订单页URL", "订单管理URL")
    products = @("products_url", "productsUrl", "productsURL", "ProductsURL", "product_url", "ProductURL", "商品链接", "商品页链接", "商品管理链接", "产品链接", "产品管理链接", "商品URL", "商品页URL", "商品管理URL", "产品URL", "产品管理URL")
    inventory = @("inventory_url", "inventoryUrl", "inventoryURL", "InventoryURL", "stock_url", "StockURL", "warehouse_url", "WarehouseURL", "库存链接", "库存URL", "仓库链接", "仓库URL", "仓储链接", "仓储URL")
    ads = @("ads_url", "adsUrl", "adsURL", "AdsURL", "广告链接", "广告页链接", "广告URL", "广告页URL")
    marketing = @("marketing_url", "marketingUrl", "marketingURL", "MarketingURL", "promotion_url", "PromotionURL", "营销链接", "营销中心链接", "营销URL", "营销中心URL")
    business = @("business_url", "businessUrl", "businessURL", "BusinessURL", "商业分析链接", "数据中心链接", "生意参谋链接", "商业分析URL", "数据中心URL", "生意参谋URL")
    traffic = @("traffic_url", "trafficUrl", "trafficURL", "TrafficURL", "visitors_url", "VisitorsURL", "流量链接", "流量URL", "访客链接", "访客URL", "转化链接", "转化URL")
    finance = @("finance_url", "financeUrl", "financeURL", "FinanceURL", "wallet_url", "WalletURL", "settlement_url", "SettlementURL", "billing_url", "BillingURL", "财务链接", "财务URL", "钱包链接", "钱包URL", "结算链接", "结算URL", "账单链接", "账单URL")
    chat = @("chat_url", "chatUrl", "chatURL", "ChatURL", "messages_url", "MessagesURL", "inbox_url", "InboxURL", "客服链接", "客服URL", "聊天链接", "聊天URL", "消息链接", "消息URL")
    reviews = @("reviews_url", "reviewsUrl", "reviewsURL", "ReviewsURL", "review_url", "ReviewURL", "ratings_url", "RatingsURL", "评价链接", "评价URL", "评论链接", "评论URL", "星级链接", "星级URL")
    vouchers = @("vouchers_url", "vouchersUrl", "vouchersURL", "VouchersURL", "voucher_url", "VoucherURL", "coupon_url", "CouponURL", "优惠券链接", "优惠券URL", "折扣券链接", "折扣券URL")
    campaigns = @("campaigns_url", "campaignsUrl", "campaignsURL", "CampaignsURL", "campaign_url", "CampaignURL", "活动链接", "活动URL", "活动报名链接", "活动报名URL", "大促链接", "大促URL")
    livestream = @("livestream_url", "livestreamUrl", "livestreamURL", "LivestreamURL", "live_url", "LiveURL", "直播链接", "直播URL")
    affiliate = @("affiliate_url", "affiliateUrl", "affiliateURL", "AffiliateURL", "creator_url", "CreatorURL", "influencer_url", "InfluencerURL", "联盟链接", "联盟URL", "达人链接", "达人URL", "分销链接", "分销URL")
    logistics = @("logistics_url", "logisticsUrl", "logisticsURL", "LogisticsURL", "shipping_url", "ShippingURL", "fulfillment_url", "FulfillmentURL", "物流链接", "物流URL", "发货链接", "发货URL", "履约链接", "履约URL")
    returns = @("returns_url", "returnsUrl", "returnsURL", "ReturnsURL", "refund_url", "RefundURL", "return_refund_url", "ReturnRefundURL", "售后链接", "售后URL", "退款链接", "退款URL", "退货链接", "退货URL", "退货退款链接", "退货退款URL")
    compass = @("compass_url", "compassUrl", "compassURL", "CompassURL", "Compass URL", "Compass链接", "罗盘链接", "Compass页URL", "罗盘URL")
    dashboard = @("dashboard_url", "dashboardUrl", "dashboardURL", "DashboardURL", "Dashboard URL", "dashboard链接", "看板链接", "看板URL")
    discovery = @("discovery_url", "discoveryUrl", "discoveryURL", "DiscoveryURL", "Discovery URL", "discovery链接", "推广发现链接", "推广发现URL")
    smax = @("smax_url", "smaxUrl", "smaxURL", "SmaxURL", "SMAXURL", "MaxURL", "Max URL", "全效宝链接", "Max链接", "全效宝URL", "全站推广URL")
  }
  foreach ($view in $viewMap.Keys) {
    $url = Get-Field $row $viewMap[$view]
    if ($url) {
      $views[$view] = @{ url = $url }
    }
  }

  $shops += [ordered]@{
    name = $name
    platform = $platform
    country = $country
    aliases = $aliases
    open_method = $openMethod
    ziniao_name = $ziniaoName
    browser_oauth = $browserOauth
    browser_id = $browserId
    views = $views
  }
}

$payload = [ordered]@{
  version = 1
  updated_at = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  source = "csv"
  source_file = $CsvPath
  shops = $shops
}

$json = $payload | ConvertTo-Json -Depth 20
Set-Content -LiteralPath $OutPath -Value $json -Encoding UTF8
Write-Host "Wrote $($shops.Count) shops to $OutPath"
