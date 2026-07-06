param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$Store,

  [Parameter(Mandatory = $false, Position = 1)]
  [string]$Intent = "打开店铺操作一下",

  [ValidateSet("", "shopee", "tiktok", "lazada")]
  [string]$Platform = "",

  [string]$Workflow = "",
  [string]$TimeRange = "",
  [int]$LoginTimeoutSeconds = 1800,
  [int]$FastOpenTimeoutSeconds = 15,
  [switch]$PlanOnly,
  [switch]$Json
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath $PSScriptRoot).Path
$workflowPath = Join-Path $root "references\ops-workflows.json"
$openStorePath = Join-Path $root "open-store.ps1"
$taskScriptPath = Join-Path $root "scripts\new-ops-task.ps1"

function Write-Result($Payload, [int]$Code = 0) {
  if ($Json) {
    $Payload | ConvertTo-Json -Depth 12
  } else {
    if ($Payload.message) { Write-Host $Payload.message }
    if ($Payload.workflow) { Write-Host ("Workflow: {0}" -f $Payload.workflow.id) }
    if ($Payload.first_view) { Write-Host ("First view: {0}" -f $Payload.first_view) }
    if ($Payload.open_command) { Write-Host ("Open command: {0}" -f $Payload.open_command) }
    if ($Payload.next_steps) {
      Write-Host "Next steps:"
      foreach ($step in @($Payload.next_steps)) { Write-Host ("- {0}" -f $step) }
    }
    if ($Payload.user_can_say) {
      Write-Host "Users can say:"
      foreach ($item in @($Payload.user_can_say)) { Write-Host ("- {0}" -f $item) }
    }
  }
  exit $Code
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

function Find-Workflow($Config, [string]$WorkflowId, [string]$Text) {
  $workflows = @($Config.workflows)
  if ($WorkflowId) {
    $match = $workflows | Where-Object { $_.id -eq $WorkflowId } | Select-Object -First 1
    if ($match) { return $match }
    throw "Unknown workflow id: $WorkflowId"
  }

  $needle = " $Text ".ToLowerInvariant()
  foreach ($wf in $workflows) {
    foreach ($phrase in @($wf.phrases)) {
      if ($phrase -and $needle.Contains(([string]$phrase).ToLowerInvariant())) {
        return $wf
      }
    }
  }

  $fallback = $workflows | Where-Object { $_.id -eq "quick_start" } | Select-Object -First 1
  if ($fallback) { return $fallback }
  return ($workflows | Where-Object { $_.id -eq "overview" } | Select-Object -First 1)
}

function Get-ViewPlaybook([string]$View) {
  $map = @{
    home = @{
      label = "店铺首页"
      targets = @("首页", "Home", "Seller Center")
      read = @("确认已进入卖家后台", "查看是否有红点/待处理事项")
    }
    overview = @{
      label = "全部数据/总览"
      targets = @("总览", "概览", "数据中心", "Dashboard", "Overview", "Business Insights", "Compass")
      read = @("销售额", "订单数", "访客/流量", "转化率", "待处理告警")
    }
    orders = @{
      label = "订单"
      targets = @("订单", "待发货", "Orders", "My Orders")
      read = @("待发货", "即将超时", "取消订单", "异常订单")
    }
    products = @{
      label = "商品"
      targets = @("商品", "产品", "Listings", "Products")
      read = @("在线商品", "下架/违规商品", "需要优化的 SKU")
    }
    inventory = @{
      label = "库存"
      targets = @("库存", "仓库", "Stock", "Inventory")
      read = @("缺货 SKU", "低库存 SKU", "库存异常")
    }
    ads = @{
      label = "广告"
      targets = @("广告", "投流", "Shopee Ads", "Ads", "Sponsored", "Campaign")
      read = @("花费", "销售额", "ROAS/ACOS", "点击率", "异常计划")
    }
    marketing = @{
      label = "营销"
      targets = @("营销中心", "营销", "Marketing", "Promotions")
      read = @("正在进行的活动", "优惠券", "报名机会")
    }
    business = @{
      label = "经营分析"
      targets = @("数据中心", "商业分析", "经营分析", "Business Insights", "Analytics")
      read = @("销售趋势", "流量", "转化率", "客单价")
    }
    traffic = @{
      label = "流量"
      targets = @("流量", "访客", "Traffic", "Visitors")
      read = @("访客", "曝光", "点击", "转化")
    }
    finance = @{
      label = "财务"
      targets = @("财务", "钱包", "结算", "Finance", "Wallet", "Payout")
      read = @("可用余额", "待结算", "手续费", "异常账单")
    }
    chat = @{
      label = "客服"
      targets = @("客服", "聊天", "消息", "Chat", "Messages", "Inbox")
      read = @("未读消息", "回复超时风险", "客户投诉")
    }
    reviews = @{
      label = "评价"
      targets = @("评价", "评论", "Reviews", "Ratings")
      read = @("差评", "低星评价", "待回复评价")
    }
    returns = @{
      label = "售后退款"
      targets = @("售后", "退款", "退货", "Returns", "Refunds")
      read = @("退款退货", "待处理售后", "争议风险")
    }
    logistics = @{
      label = "物流"
      targets = @("物流", "发货", "Shipping", "Logistics")
      read = @("待发货", "延迟发货", "物流异常")
    }
    vouchers = @{
      label = "优惠券"
      targets = @("优惠券", "Coupons", "Vouchers")
      read = @("优惠券状态", "使用量", "即将过期")
    }
    campaigns = @{
      label = "活动"
      targets = @("活动", "Campaigns", "Promotions")
      read = @("活动报名", "活动状态", "可参加机会")
    }
    livestream = @{
      label = "直播"
      targets = @("直播", "Live", "Livestream")
      read = @("直播状态", "直播销售", "待配置事项")
    }
    affiliate = @{
      label = "联盟/达人"
      targets = @("联盟", "达人", "Affiliate", "Creator")
      read = @("联盟销售", "达人合作", "佣金状态")
    }
    compass = @{
      label = "罗盘/Compass"
      targets = @("Compass", "罗盘", "数据罗盘")
      read = @("销售", "流量", "转化", "异常趋势")
    }
    dashboard = @{
      label = "Dashboard"
      targets = @("Dashboard", "看板", "仪表盘")
      read = @("核心 KPI", "待处理事项", "异常提醒")
    }
    discovery = @{
      label = "Discovery"
      targets = @("Discovery", "推广发现")
      read = @("推广表现", "机会项", "异常花费")
    }
    smax = @{
      label = "全效宝/SMAX"
      targets = @("全效宝", "SMAX", "Max 全站推广", "Sponsored Max")
      read = @("花费", "ROAS", "计划状态", "异常计划")
    }
  }
  if ($map.ContainsKey($View)) { return $map[$View] }
  return @{ label = $View; targets = @($View); read = @("读取当前页面可见数据") }
}

if (!(Test-Path -LiteralPath $workflowPath)) {
  Write-Result ([ordered]@{
    ok = $false
    error = "workflow_file_missing"
    message = "Workflow definition not found."
    path = $workflowPath
  }) 1
}
if (!(Test-Path -LiteralPath $openStorePath)) {
  Write-Result ([ordered]@{
    ok = $false
    error = "open_store_missing"
    message = "open-store.ps1 is missing."
    path = $openStorePath
  }) 1
}

$config = [System.IO.File]::ReadAllText($workflowPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
$workflowObj = Find-Workflow $config $Workflow $Intent
if (!$workflowObj) {
  Write-Result ([ordered]@{
    ok = $false
    error = "workflow_not_resolved"
    message = "Could not resolve a workflow for this request."
    intent = $Intent
  }) 1
}

$views = @($workflowObj.views | ForEach-Object { [string]$_ })
if ($views.Count -eq 0) { $views = @("overview") }
$firstView = $views[0]
$playbook = Get-ViewPlaybook $firstView
$remainingViews = @($views | Select-Object -Skip 1)

$taskJson = $null
if (Test-Path -LiteralPath $taskScriptPath) {
  $taskArgs = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", $taskScriptPath,
    "-Store", $Store,
    "-Intent", $Intent,
    "-Workflow", ([string]$workflowObj.id),
    "-Json"
  )
  if ($Platform) { $taskArgs += @("-Platform", $Platform) }
  if ($TimeRange) { $taskArgs += @("-TimeRange", $TimeRange) }
  $taskOutput = @(& powershell @taskArgs 2>&1)
  $taskJson = ConvertFrom-JsonOutput $taskOutput
}

$openCommand = ".\open-store.ps1 `"$Store`" -View $firstView"
$openJson = $null
$openCode = 0
$rawOpenOutput = $null
if (!$PlanOnly) {
  $openArgs = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", $openStorePath,
    $Store,
    "-View", $firstView,
    "-LoginTimeoutSeconds", ([string]$LoginTimeoutSeconds),
    "-FastOpenTimeoutSeconds", ([string]$FastOpenTimeoutSeconds),
    "-Json"
  )
  if ($Platform) { $openArgs += @("-Platform", $Platform) }
  $rawOpenOutput = @(& powershell @openArgs 2>&1)
  $openCode = $LASTEXITCODE
  $openJson = ConvertFrom-JsonOutput $rawOpenOutput
}

$nextSteps = @(
  "确认当前页不是登录页；如果是登录页，员工在本机手动登录后重新说同一句话。",
  "如果有弹窗，只关闭安全按钮：关闭 / 跳过 / 稍后 / 我知道了 / Not now / Got it。",
  ("在当前页找这些入口或标题：{0}" -f ((@($playbook.targets)) -join " / ")),
  ("优先读取这些可见信息：{0}" -f ((@($playbook.read)) -join " / "))
)
foreach ($view in $remainingViews) {
  $nextSteps += ("后续需要再看 `{0}`，可继续运行：.\open-store.ps1 `"{1}`" -View {0}" -f $view, $Store)
}
$nextSteps += "所有动作默认只读；发布、付款、退款、改价、改广告预算、发消息前必须停下来让用户确认。"

$payload = [ordered]@{
  ok = (($PlanOnly) -or ($openCode -eq 0))
  message = if ($PlanOnly) { "已生成店铺操作计划，未打开店铺。" } elseif ($openCode -eq 0) { "已按用户意图打开店铺并生成下一步操作向导。" } else { "店铺打开未完成，已返回下一步排查信息。" }
  store = $Store
  intent = $Intent
  platform = $Platform
  workflow = [ordered]@{
    id = [string]$workflowObj.id
    name = [string]$workflowObj.name
    views = $views
    required_metrics = @($workflowObj.required_metrics)
    questions = @($workflowObj.questions)
  }
  first_view = $firstView
  first_view_playbook = [ordered]@{
    label = [string]$playbook.label
    visual_targets = @($playbook.targets)
    read_first = @($playbook.read)
  }
  task_path = if ($taskJson -and $taskJson.path) { [string]$taskJson.path } else { "" }
  open_command = $openCommand
  opened = if ($PlanOnly) { $null } else { $openJson }
  raw_open_output = if ($openJson -or $PlanOnly) { $null } else { $rawOpenOutput }
  next_steps = $nextSteps
  user_can_say = @(
    "打开 <店铺关键词> 全部数据",
    "看 <店铺关键词> 广告数据",
    "处理 <店铺关键词> 订单",
    "给 <店铺关键词> 做今日巡店",
    "看 <店铺关键词> 客服售后",
    "看 <店铺关键词> 商品库存"
  )
  safety = @($config.safe_rules)
}

Write-Result $payload $openCode
