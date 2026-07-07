# Ziniao Ops

> 位置：可以放在员工电脑任意目录。运行 `install-codex-skill.ps1` 后，会把真实目录写到 Codex home 下的 `ziniao-ops.json`，Codex 按这个配置找包。
> 仓库：`https://github.com/xobi667/ziniao-ops.git`。Skill 名称固定为 `ziniao-ops`。

这套包给员工电脑本地使用：员工自己的 Codex 负责理解“打开哪家店”，本地脚本负责扫描员工电脑上的紫鸟店铺浏览器、生成本机店铺缓存，并打开对应浏览器/紫鸟/已登录后台。CSV 或可选的 Lark/Feishu CLI 只作为补充导入方式。

这不是紫鸟官方产品，也不复制或内置第三方项目代码。它吸收了 Vibe Seller、auto-ziniao/OpenClaw、ziniao/ziniao-mcp 和通用浏览器自动化 skill 的有用设计，并提供本地上游同步和可选适配器；默认仍保持轻量：不要求员工填 LLM Key、不保存紫鸟密码、不启动长期 Web 服务。

重要边界：这套包不登录账号、不保存密码、不复制浏览器会话数据、不处理验证码。员工电脑必须已经登录对应店铺账号。没登录时平台会跳到登录页，这属于正常结果；员工需要在本机手动登录后重新执行同一个开店命令。

## 环境支持

| 环境 | 支持情况 | 说明 |
| --- | --- | --- |
| Windows 10/11 + Codex + 紫鸟 | 完整支持 | Shopee/TikTok 走紫鸟 webdriver/API；Lazada 走紫鸟 GUI。 |
| Windows PowerShell 5.1 | 支持 | 中文脚本已按 Windows 兼容处理。 |
| PowerShell 7+ | 支持 | 推荐用于新电脑。 |
| macOS/Linux/WSL | 仅配置/模板/诊断 | 紫鸟桌面自动化依赖 Windows；这些环境不能精准打开紫鸟店铺。 |
| 未登录紫鸟或店铺后台 | 只能打开到登录页 | 必须员工本机手动登录后重试。 |

最稳的员工电脑准备项：

- Windows 10/11。
- 已安装并登录 Codex。
- 已安装并登录紫鸟。
- 目标店铺后台已在本机登录过。
- Python 3 可用；Lazada 还需要运行一次 `.\install-python-deps.ps1`。
- 紫鸟里已经有员工本人负责的店铺浏览器；`shops.json` 会自动从本机紫鸟扫描生成。

## 新手安装

推荐从 GitHub Releases 下载 zip，解压后进入 `ziniao-ops` 文件夹，右键用 PowerShell 打开，运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

`install.ps1` 是新手入口。它会：

- 检查 Windows、PowerShell、Python、Node/npm、Git、磁盘空间、紫鸟配置。
- 询问依赖、虚拟环境、Playwright 浏览器文件要安装到哪个目录，默认是当前包内的 `.ziniao-ops`，也可以输入 D/E 盘目录。
- 如果缺 Python/Node/Git，会先询问是否允许用 `winget` 自动安装。
- 安装 Codex skill，并写入 Codex home 下的 `ziniao-ops.json`。
- 默认询问是否安装紫鸟 GUI/Lazada 依赖 `pywinauto`，依赖会落到本地 Python venv，不要求塞进 C 盘。
- 默认询问是否安装可选上游增强工具：`ziniao` CLI、`auto-ziniao`、BrowserMCP server、Vibe Seller、Playwright Chromium。
- 自动进入一次紫鸟就绪检查：默认只尝试非鼠标 WebDriver/API 通道，不置顶窗口、不移动鼠标；如果紫鸟登录态无效，会提示员工手动打开并登录紫鸟。只有明确运行 `setup-ziniao.ps1 -AllowGuiMouse` 时，才允许前台登录交接。

如果要同时安装 Lazada GUI 依赖：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -InstallLazadaDeps
```

如果要完整自动安装，适合负责人批量部署：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -NonInteractive -InstallLazadaDeps -InstallOptionalTools -InstallMissingRuntimes -LocalToolsRoot "D:\ziniao-ops-tools"
```

如果 C 盘很小，不要把 `-LocalToolsRoot` 指到 C 盘。Vibe Seller 和 Playwright 浏览器文件体积较大，建议放 D/E 盘。

如果开发者或负责人要把可选上游工具也装齐，用：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-upstream-tools.ps1
```

它会尽量安装：

- PyPI `ziniao` CLI 到本地 venv，并创建本地 `ziniao` 命令包装器。
- npm `@ww-ai-lab/auto-ziniao` 到本地 npm prefix，用于可选 flow engine 路线。
- npm `@browsermcp/mcp` 到本地 npm prefix，用于可选 BrowserMCP server 路线。
- PyPI `vibe-seller` 到本地 `.ziniao-ops\tools` 或你指定的 `-LocalStateRoot`，并把 Playwright Chromium 下载到同一个本地依赖目录。

这些都是可选增强，不是普通员工开店的前置条件。`auto-ziniao` 真正跑流程仍需要员工自己配置 `ZCLAW_API_KEY`；BrowserMCP 仍需要安装/连接 Chrome 扩展和 MCP 客户端；Vibe Seller 不会自动启动长期服务，也需要单独配置 LLM key 和店铺环境。

检查这台电脑装到了什么：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\status-upstream-adapters.ps1
```

如果安装时不方便登录紫鸟，可以先跳过紫鸟检查：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -SkipZiniaoSetup
```

之后再运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup-ziniao.ps1
```

然后重启 Codex，直接对 Codex 说：`打开 <店铺关键词> 操作一下`、`打开 <店铺关键词> 全部数据`、`打开 <店铺关键词> 订单数据` 或 `打开 <店铺关键词> 广告数据`。

首次成功准备紫鸟时，脚本会自动扫描本机紫鸟里的店铺浏览器，生成本机 `shops.json` 缓存。员工不需要手工填店铺清单。

Codex 实际操作店铺时会优先走 `operate-store.ps1`：它会判断用户想做什么、打开第一个相关页面，并返回下一步操作向导。只开店铺环境时才走 `open-store.ps1`。默认路径只尝试本机紫鸟 WebDriver/API，不复用前台窗口、不点击可见店铺行；如果紫鸟登录态不可用，会提示员工手动登录后重试。只有员工明确接受前台 GUI 控制并加 `-AllowGuiMouse` 时，才会复用当前紫鸟窗口、搜索可见店铺行或点击“启动/切换”按钮。如果紫鸟要求验证码或安全验证，员工必须自己完成。

如果 Windows 提示脚本来自互联网被阻止，先在解压目录运行：

```powershell
Get-ChildItem -Recurse -File | Unblock-File
```

开发者也可以从 GitHub 仓库 clone：

```powershell
git clone https://github.com/xobi667/ziniao-ops.git ziniao-ops
cd ziniao-ops
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

旧安装入口仍可用：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install-codex-skill.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup-ziniao.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\diagnose-local.ps1
```

安装脚本也会尝试自动发现本机紫鸟路径，并写入同目录的 `ziniao.local.json`。如果没发现也没关系：员工先手动打开并登录紫鸟，或者把本机紫鸟 exe 路径填到 `ziniao.local.json` 的 `client_path`。

重复安装时，旧 skill 会备份到 Codex home 下的 `skill-backups`，不会留在 `skills` 目录里干扰 Codex 识别。

## 本地店铺清单

- `shops.json` 是员工电脑本地缓存，默认从本机紫鸟浏览器列表自动生成。
- GitHub 仓库不提交 `shops.json`；安装脚本会在员工电脑本机创建空缓存，首次开店时会自动扫描紫鸟填充。
- `.gitignore` 已忽略 `shops.json`、`ziniao.local.json`、`.env`、zip、日志和缓存，避免误提交本机数据。
- `shops.example.json` 是示例，不要直接当生产清单。
- `shops.template.json` 是空模板，只在需要手工补充时使用。
- 不要在任何文件里存密码、验证码、浏览器会话数据、token。

手工补充时的最小格式：

```json
{
  "shops": [
    {
      "name": "EXAMPLE_SHOPEE_MY",
      "platform": "shopee",
      "aliases": ["example shopee my", "example-my-sp"],
      "views": {
        "overview": {"url": "https://seller.shopee.com.my/datacenter/overview"},
        "orders": {"url": "https://seller.shopee.com.my/portal/sale/order"},
        "ads": {"url": "https://seller.shopee.com.my/portal/marketing/pas/index"}
      }
    }
  ]
}
```

## 直接用脚本打开

更推荐的一句话操作入口：

```powershell
.\operate-store.ps1 "<店铺关键词>" "打开店铺操作一下"
.\operate-store.ps1 "<店铺关键词>" "看全部数据"
.\operate-store.ps1 "<店铺关键词>" "处理订单"
.\operate-store.ps1 "<店铺关键词>" "看广告数据"
.\operate-store.ps1 "<店铺关键词>" "做今日巡店"
```

`operate-store.ps1` 会先判断用户意图，生成只读任务计划，打开第一个相关页面，并返回下一步要找什么入口、读什么指标、哪些按钮不能点。面向普通员工时，Codex 应优先用这个入口。

只打开店铺环境时再用：

```powershell
.\open-store.ps1 "example shopee my" -View overview
.\open-store.ps1 "example shopee my" -View orders
.\open-store.ps1 "example shopee my" -View ads
.\open-store.ps1 "example tiktok id" -View compass
.\open-store.ps1 "example lazada my" -View dashboard
```

`open-store.ps1` 是员工的一句话入口：默认通过非鼠标 WebDriver/API 打开本机店铺环境；如果本机紫鸟登录态不可用，会停止并提示员工手动登录后重试。只有显式加 `-AllowGuiMouse` 时，才允许聚焦紫鸟窗口、GUI 搜索或前台点击。加了 `-AllowGuiMouse` 后会直接进入基础开店链路，不再先卡 `setup/sync/shops.json`。

注意：基础开店和后台页面验证是两件事。脚本可能返回 `window_verified=false`，表示已经在紫鸟里点击了目标店铺的“启动/切换”，但还没确认新后台窗口出现。此时只能说“已在本机紫鸟中发起店铺打开”，不能说“已经进入后台”。只有看到 seller 后台 URL、标题或页面内容后，才算进入后台。

只测试匹配，不打开：

```powershell
.\open-shop.ps1 "example shopee my" -View orders -DryRun
```

刷新本机紫鸟店铺缓存：

```powershell
.\open-shop.ps1 -List -RefreshZiniao
```

默认不会抢鼠标、置顶窗口或走 pywinauto GUI 点击。只有员工接受前台 GUI 控制时，才使用 `.\open-shop.ps1 "<店铺关键词>" -AllowGuiMouse`。默认也不会强制结束或重启紫鸟；只有员工确认当前紫鸟可以被重启时，才额外使用 `-AllowRestart`。

## 运营助理工作流

`ziniao-ops` 不只负责打开页面。现在可以先生成运营任务，再让 Codex 按任务逐项打开页面、读取可见指标、形成报告。

生成单店任务：

```powershell
.\scripts\new-ops-task.ps1 -Store "example shopee my" -Intent "巡店日报" -Platform shopee
.\scripts\new-ops-task.ps1 -Store "example shopee my" -Intent "广告数据复盘" -Platform shopee
.\scripts\new-ops-task.ps1 -Store "example tiktok id" -Intent "客服售后风险" -Platform tiktok
```

生成批量巡店清单：

```powershell
.\scripts\new-ops-batch.ps1 -Store "example shopee my","example tiktok id" -Workflow daily_check
```

从 CSV 生成批量巡店清单：

```powershell
.\scripts\new-ops-batch.ps1 -InputCsv .\shops.csv -Workflow daily_check
```

生成运营报告：

```powershell
.\scripts\new-ops-report.ps1 -Store "example shopee my" -Platform shopee -Workflow daily_check -View overview -MetricsJson "{}" -Findings "销售额正常" -Risks "有未读客服消息" -Recommendations "先处理客服消息"
```

发送报告到飞书/Lark 前先 dry-run：

```powershell
.\scripts\send-ops-report-lark.ps1 -ReportPath ".\reports.local\example.md" -ReceiveId "<chat_id>"
.\scripts\send-ops-report-lark.ps1 -ReportPath ".\reports.local\example.md" -ReceiveId "<open_id>" -ReceiveIdType open_id
```

群聊 `ReceiveId` 使用 `oc_...`；私聊使用飞书 `open_id`，也就是 `ou_...`。确认目标会话和命令没问题后才加 `-AllowSend`。报告里如果出现密码、验证码、cookie、token、session 等敏感词，脚本会拒绝发送。

内置工作流定义在 `references\ops-workflows.json`，说明见 `references\ops-workflows.md`。当前包含：

- `daily_check`：每日巡店/店铺体检。
- `overview`：整体数据总览。
- `ads`：广告投放复盘。
- `orders`：订单/发货检查。
- `products`：商品/库存检查。
- `inventory`：缺货、低库存、补货风险。
- `traffic`：流量、曝光、点击、转化检查。
- `finance`：财务/结算检查。
- `reviews`：评价、评论、差评风险。
- `logistics`：物流、履约、面单、发货风险。
- `returns`：售后、退款、退货风险。
- `service`：客服、消息、回复超时风险。
- `compliance`：商品违规、下架、账号健康风险。
- `creative`：商品素材、主图、视频优化入口。
- `marketing`：营销、优惠券、活动、直播、联盟检查。

## 精准打开方式

默认不是简单打开 URL，也不是强制固定跳某个页面；默认只是精准打开员工本机对应店铺环境，然后让 Codex 视觉点击进入订单、商品、库存、广告、经营分析、财务、客服、评价、物流、售后或平台专属页面。

- Shopee / TikTok：默认走本机紫鸟 webdriver/API，匹配 `ziniao_name` / `browser_oauth` / `browser_id` 后启动对应紫鸟店铺环境；这条路径不需要抢鼠标。如果 API 登录态异常，默认停止并提示，只有明确加 `-AllowGuiMouse` 才退回紫鸟 GUI 搜索和点击。
- Lazada：当前精准路径依赖本机紫鸟 GUI/pywinauto，会前台聚焦窗口并可能移动鼠标；默认停止并提示，只有明确加 `-AllowGuiMouse` 才执行。
- 如果精准打开失败，默认不会偷偷降级成普通 URL，避免串到错误账号。
- 只有明确加 `-UrlFallback` 才允许精准失败后退回普通链接打开。
- 只有明确加 `-NavigateView` 才会在开店后强制跳 `views` 里的 URL。
- 自动扫描出来的店铺如果没有视图 URL，会先打开紫鸟店铺环境，再由 Codex 视觉点击目标运营模块；手工维护的视图缺 URL 仍会失败。
- 如果需要复用当前紫鸟窗口里的可见店铺行，必须显式加 `-AllowGuiMouse`，因为这会使用前台窗口和鼠标点击。
- 如果返回紫鸟登录态错误，说明 WebDriver/API 已通但当前紫鸟没有有效登录上下文；员工在本机手动打开并登录紫鸟后重新说同一句开店命令。只有员工接受前台窗口/鼠标控制时，才改用 `-AllowGuiMouse`。
- `open_command` 默认不会执行；只有确认 `shops.json` 可信并明确加 `-AllowCommand` 才允许执行本地命令。

示例：

```powershell
.\open-shop.ps1 "example shopee my" -View overview
.\open-shop.ps1 "example shopee my" -View finance
.\open-shop.ps1 "example tiktok id" -View compass
.\open-shop.ps1 "example lazada my" -View dashboard
```

强制跳具体 URL：

```powershell
.\open-shop.ps1 "example shopee my" -View ads -NavigateView
```

允许目标视图缺失时退回首页：

```powershell
.\open-shop.ps1 "example shopee my" -View ads -AllowHomeFallback
```

Lazada 精准打开需要员工电脑安装可选依赖：

```powershell
.\install-python-deps.ps1
```

检查本机还缺什么：

```powershell
.\diagnose-local.ps1
```

准备/修复紫鸟首登和本机店铺缓存。默认不置顶窗口、不移动鼠标：

```powershell
.\setup-ziniao.ps1
```

如果员工明确接受前台紫鸟窗口和鼠标/焦点控制，再运行：

```powershell
.\setup-ziniao.ps1 -AllowGuiMouse
```

把诊断结果里的 `issues` 和 `next_steps` 发给负责人即可。常见判断：

- `ziniao_shops_unavailable`：本机没有可用店铺缓存，并且扫描紫鸟失败。先运行 `.\setup-ziniao.ps1` 做非鼠标检查；如果诊断显示登录态错误，员工手动打开并登录紫鸟后重试。
- `ziniao_sync_login_error_seen`：WebDriver/API 可达，但紫鸟返回登录态错误。手动登录紫鸟后重试；只有接受前台控制时才用 `.\setup-ziniao.ps1 -AllowGuiMouse`。
- `can_sync_ziniao_shops`：如果为 `true`，说明能从本机紫鸟自动生成店铺缓存。
- `python_missing`：这台电脑没装 Python 3。
- `ziniao_path_not_detected`：没找到紫鸟 exe，先手动打开紫鸟或填 `ziniao.local.json`。
- `ziniao_webdriver_not_reachable`：紫鸟没登录、没打开、端口不通，Shopee/TikTok 精准开店会失败。先运行 `.\setup-ziniao.ps1`；只有接受前台控制时才加 `-AllowGuiMouse`。
- `pywinauto_missing_for_lazada`：Lazada 精准开店需要先运行 `install-python-deps.ps1`。

只想普通浏览器打开链接时：

```powershell
.\open-shop.ps1 "example shopee my" -View ads -UrlOnly
```

## 在 Codex 里说

安装 skill 后，员工可以直接对自己电脑上的 Codex 说：

- 打开 example shopee my 广告页
- 打开 example shopee my 全部数据
- 给 example shopee my 做今日巡店
- 给 example shopee my 生成运营日报
- 批量巡店 example shopee my 和 example tiktok id
- 把刚才的运营报告发飞书
- 看 example shopee my 订单数据
- 打开 example shopee my 财务
- 看 example shopee my 客服消息
- 打开 example shopee my 售后退款
- 打开 example tiktok id 的 compass
- 打开 example lazada my 的 dashboard
- 进入 example shopee my 广告后台
- 看 example shopee my 数据中心
- 打开 Lazada 全效宝
- 店铺打不开，帮我自检
- 紫鸟打不开，帮我看本机缺什么
- 页面被广告弹窗挡住了，帮我跳过

Codex 应使用：

```powershell
$codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE ".codex" }
$cfg = Get-Content (Join-Path $codexHome "ziniao-ops.json") -Raw | ConvertFrom-Json
& (Join-Path $cfg.package_root "open-store.ps1") "<店铺关键词>" -View <视图>
```

`<视图>` 是运营模块意图，不只是广告。常用值包括 `overview`、`orders`、`products`、`inventory`、`ads`、`marketing`、`business`、`traffic`、`finance`、`chat`、`reviews`、`vouchers`、`campaigns`、`livestream`、`affiliate`、`logistics`、`returns`、`compass`、`dashboard`、`discovery`、`smax`。如果员工说“全部数据”，先用 `overview`，读可见总览指标；要逐项全查时再进入各模块。

Codex 回复时不要说“已经成功进入后台”，只能说“已在本机发起店铺打开”。如果员工看到登录页，就让员工本机手动登录后重试。

## 本机不适配时

如果员工电脑路径、紫鸟安装位置、Python、Lazada GUI、窗口语言或店铺别名不一样，不要硬猜。让员工把 `本机适配修复提示词.txt` 发给他电脑上的 Codex。

这个提示词会要求对方 Codex：

- 先运行 `diagnose-local.ps1`。
- 只修改这个员工电脑里的 `ziniao-ops` 包。
- 不碰主项目、不碰密码、不碰浏览器会话数据、不绕过登录。
- 改完重新运行诊断和 `open-shop.ps1 ... -DryRun -Json`。
- 汇报改了什么、还缺什么、哪个店铺匹配到了什么。

## 弹窗处理

店铺打开后，Codex 可以靠视觉点击处理阻挡页面的广告/教程/公告弹窗：

- 优先点右上角 `X`。
- 可以点 `关闭`、`跳过`、`稍后`、`以后再说`、`我知道了`、`不再提示`、`Close`、`Skip`、`Later`、`Not now`。
- 不能点会创建广告、提交、付款、修改设置、发布内容的按钮。
- 看不懂或没有安全关闭按钮时，停下来问员工。

## CSV / Lark CLI 的角色

默认不需要 CSV 或 Lark/Feishu CLI；本机紫鸟里有什么店铺，就自动生成什么店铺缓存。CSV 或 Lark/Feishu CLI 不直接开店，只作为需要补充 URL、别名或人工主数据时的导入方式。开店动作仍然发生在员工本机。

如果自动扫描的店铺名不够好匹配，或需要补充固定页面 URL，可以让有权限的人导出 CSV/JSON，再写入本机 `shops.json`。

从 CSV 生成本地清单：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\import-shops-csv.ps1 .\shops.csv
```

CSV 导入会优先按 UTF-8 读取，失败时自动退回系统默认编码，以兼容部分 Windows/Excel 导出的中文 CSV。

CSV 常用字段：`店铺名称`、`平台`、`国家`、`别名`，以及 `总览URL`、`订单URL`、`商品URL`、`库存URL`、`广告页URL`、`营销中心URL`、`商业分析URL`、`流量URL`、`财务URL`、`客服URL`、`评价URL`、`优惠券URL`、`活动URL`、`直播URL`、`联盟URL`、`物流URL`、`售后URL`、`CompassURL`、`看板URL`、`DiscoveryURL`、`全效宝URL` 等固定页面列。

仓库里提供 `shops.csv.example`，员工可以复制成 `shops.csv` 后填自己的店铺，再导入。

## 参考项目

这个包参考但不依赖这些项目：

- Vibe Seller：本地优先、多店铺隔离、CDP/浏览器控制、任务报告思路。它是完整卖家 Agent 框架；本包只做 Codex skill + 本机脚本。
- auto-ziniao / Ziniao Assistant / OpenClaw：可作为未来可选的 key-based 路线；本包默认不要求 `ZCLAW_API_KEY`，也不复制其个人/内部自用许可代码。
- ziniao / ziniao-mcp：可作为后续 CLI/MCP 可选路线；本包当前默认仍走员工本机紫鸟 UI/WebDriver。
- 通用 browser automation skills：用于确认“先确定正确本机店铺，再做视觉/浏览器操作”的分层方式。

详细取舍见 `references/external-projects.md`。

上游仓库和文档清单见 `references/upstreams.md` / `references/upstreams.json`。检查上游是否更新：

```powershell
.\scripts\check-upstreams.ps1
```

把可 Git 同步的上游 clone/fetch 到本机忽略目录 `.upstreams/`：

```powershell
.\scripts\sync-upstreams.ps1
```

检查这台电脑有哪些可选上游适配器可用：

```powershell
.\scripts\status-upstream-adapters.ps1
```

检查电商平台 API 和外部工具官方入口是否可达：

```powershell
.\scripts\check-ecommerce-tools.ps1
.\scripts\check-ecommerce-tools.ps1 -Json
.\scripts\check-ecommerce-tools.ps1 -Category market_research
.\scripts\check-ecommerce-tools.ps1 -Category official_platform_api -TimeoutSec 1 -TotalTimeoutSec 20 -MaxConcurrency 8
```

安装或补齐这些可选上游命令：

```powershell
.\scripts\install-upstream-tools.ps1
```

指定依赖目录：

```powershell
.\scripts\install-upstream-tools.ps1 -LocalStateRoot "D:\ziniao-ops-tools"
```

上游能力集成状态见 `references/upstream-integration.md`。当前规则是：

- 内置：本机紫鸟扫描、模糊匹配、开店、模块路由、诊断、报告模板。
- 可选外部适配：本机装了 `ziniao` CLI 时可走 `scripts\invoke-ziniao-cli.ps1`；本机装了 `auto-ziniao` 时可走 `scripts\invoke-auto-ziniao.ps1`；本机装了 BrowserMCP/Vibe Seller 时可作为人工批准后的外部浏览器自动化路线。
- 本地镜像同步：Vibe Seller、BrowserMCP、Codex/OpenClaw skills 清单可 clone 到 `.upstreams/` 方便后续人工合并设计。
- 参考但不复制：`auto-ziniao` 许可证是个人/内部自用，能同步到本机参考，但不能把代码直接拷进这个开源仓库。

## 电商能力地图

`ziniao-ops` 现在不只记录紫鸟开店能力，也记录跨境电商运营需要补齐的外部能力：

```powershell
.\references\ecommerce-capability-map.json
.\references\ecommerce-capability-map.md
.\references\platform-api-roadmap.md
```

覆盖范围：

- P0：Shopee、TikTok Shop、Lazada、Amazon SP-API、Amazon Ads API 等官方平台 API 路线。
- P1：市场研究、评论洞察、广告增长、素材生成。
- P2：客服、物流、财税、ERP、多渠道库存订单。
- P3：改价/调价这类高风险写操作，只记录路线，不默认自动化。

检测官方入口和外部工具状态：

```powershell
.\scripts\check-ecommerce-tools.ps1
.\scripts\check-ecommerce-tools.ps1 -Category official_platform_api
.\scripts\check-ecommerce-tools.ps1 -Category reviews_and_voice_of_customer
.\scripts\check-ecommerce-tools.ps1 -Category official_platform_api -TimeoutSec 1 -TotalTimeoutSec 20 -MaxConcurrency 8
```

规则很明确：官方 API、SaaS、MCP、付费工具都不能静默安装，也不能把店铺数据自动传出去。只有用户自己配置账号和权限后，Codex 才能按对应路线使用。

## 外部工具目录

LinkFox Agent、LinkFox AI、LinkFox Skills、Amazon Reviews、Self Improving Agent、Seller Sprite/卖家精灵这类工具记录在：

```powershell
.\references\external-tools.json
.\references\external-tools.md
```

检查官方入口和可识别版本：

```powershell
.\scripts\check-external-tools.ps1
.\scripts\check-external-tools.ps1 -Json
```

更完整的电商工具和平台 API 能力清单见 `references\ecommerce-capability-map.json`，用 `scripts\check-ecommerce-tools.ps1` 检查。

规则：

- LinkFox / Seller Sprite 这类闭源 SaaS、付费账号、第三方 skill，不会被 `install.ps1` 静默安装。
- 能自动更新的只限本地开源组件或本仓库脚本。
- 外部工具只作为可选路线：市场洞察、亚马逊评论分析、素材生成、亚马逊选品/关键词/API/MCP。
- 本地紫鸟开店、店铺巡检、运营报告不依赖这些外部工具。

## 本地自学习

如果一次开店、巡店、页面导航失败，Codex 可以把经验记录到本机忽略目录 `.ziniao-ops`：

```powershell
.\scripts\record-ops-learning.ps1 -Kind fix -Store "<店铺关键词>" -Intent "看广告数据" -Problem "广告入口不在首页" -Fix "先点营销中心再点广告"
.\scripts\show-ops-learning.ps1
```

这个日志不提交 GitHub，不保存密码、验证码、cookie、token。

## 推送前检查

每次推到 GitHub 前运行：

```powershell
.\scripts\validate-public.ps1
```

这个脚本会检查：

- 是否误提交了 `shops.json`、`ziniao.local.json`、`.env`。
- 是否出现真实店铺名、本机路径、token、table id 等敏感内容。
- PowerShell 脚本是否能解析。
- Python 脚本是否能编译。
- skill frontmatter 和 `agents/openai.yaml` 是否有效。
- 是否把截图、Excel、zip、日志、pyc 等本机产物误加入 Git 跟踪。

仓库也带了 GitHub Actions，push / pull request 时会自动跑同样的公开校验。

如果你有一批内部店铺名或公司专有词要额外防误提交，可以在本机创建 `sensitive-patterns.local.txt`，一行一个词。这个文件已被 `.gitignore` 忽略，不会进入 GitHub。

## 开源安全边界

- 不要把真实 `shops.json` 提交到 GitHub。
- 不要提交 `ziniao.local.json`、`.env`、日志、截图、浏览器会话数据、token 或密码。
- README、员工说明、脚本提示、测试命令和报告模板里不要写真实店铺名；统一使用 `<店铺关键词>`、`DEMO_*` 或 `example` 占位符。
- 仓库只放通用脚本、skill、示例和模板。
- 员工自己的店铺名、紫鸟路径、浏览器 ID 和数据源配置都只留在员工电脑本机。
