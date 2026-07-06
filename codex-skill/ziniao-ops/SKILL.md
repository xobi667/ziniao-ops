---
name: ziniao-ops
description: Open, check, troubleshoot, operate, and report on employee-local seller store backends and operational data pages from the package path recorded by install-codex-skill.ps1, using local shops.json, PowerShell scripts, Ziniao, visual clicks, read-only workflow plans, optional upstream/external-tool catalogs, local self-learning notes, and optionally lark-cli/Feishu to send reports. Use when the user asks Codex to open/check/enter/operate a Shopee, TikTok/Tokopedia, or Lazada store on the employee's own computer, or asks for LinkFox, Seller Sprite, Amazon Reviews, market research, review insights, creative tools, ziniao-ops upstream sync, ziniao CLI/MCP, auto-ziniao, Vibe Seller, BrowserMCP, including Chinese triggers such as 打开店铺, 开店铺, 进店铺后台, 店铺后台, 操作一下, 不知道点什么, 下一步, 店铺打不开, 紫鸟打不开, 登录页, 全部数据, 店铺总览, 订单, 商品, 库存, 广告, 营销, 运营数据, 数据中心, 商业分析, 生意参谋, 流量, 财务, 客服, 评价, 优惠券, 活动, 直播, 联盟, 物流, 售后, 退款, Compass, 罗盘, TikTok Shop, Tokopedia Seller Center, Lazada ASC, dashboard, discovery, 全效宝, Max 全站推广, smax, 巡店, 店铺体检, 日报, 运营报告, 批量巡店, 发飞书, LinkFox, Seller Sprite, 卖家精灵, Amazon Reviews, 评论分析, 素材生成, 上游同步, 同步更新, or 本机不适配.
---

# Ziniao Ops

Use this skill only for the employee-local quick-open package installed on the current computer. Do not use unrelated private projects or external business systems to open stores. This workflow opens stores on the current employee computer only. The employee's available stores come from the store browsers visible in this computer's local Ziniao account.

Full Ziniao automation is Windows-only. On macOS/Linux/WSL, use this skill only for configuration, diagnostics, CSV import, or explicit URL/manual fallback; do not claim precision Ziniao opening is supported there.

## Locate Package

Before running commands, resolve `$ZiniaoOpsHome`:

```powershell
$codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE ".codex" }
$cfgPath = Join-Path $codexHome "ziniao-ops.json"
if (Test-Path $cfgPath) {
  $ZiniaoOpsHome = (Get-Content $cfgPath -Raw | ConvertFrom-Json).package_root
} elseif ($env:ZINIAO_OPS_HOME) {
  $ZiniaoOpsHome = $env:ZINIAO_OPS_HOME
} elseif ($env:ZINIAO_SELLER_OPS_HOME) {
  $ZiniaoOpsHome = $env:ZINIAO_SELLER_OPS_HOME
} else {
  $legacyCfgPaths = @(
    (Join-Path $codexHome "ziniao-seller-ops.json"),
    (Join-Path $codexHome "dianpu-open-store.json")
  )
  $legacyCfgPath = $legacyCfgPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
  if ($legacyCfgPath) {
    $ZiniaoOpsHome = (Get-Content $legacyCfgPath -Raw | ConvertFrom-Json).package_root
  } else {
    throw "ziniao-ops package path is not configured. Ask the employee where the package was extracted, then run install-codex-skill.ps1 there."
  }
}
```

Then run scripts through `Join-Path $ZiniaoOpsHome ...`. The package can live in any folder.

If opening fails or the employee asks what is missing, run:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "diagnose-local.ps1")
```

If the employee is setting up this package for the first time, or if Ziniao login/cache readiness is unclear, run:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "setup-ziniao.ps1")
```

This opens or foregrounds Ziniao, waits for the employee to complete local Ziniao login, then scans the local Ziniao browser list into `shops.json`. It must not enter credentials or solve verification.

For first-time installation, prefer the package installer instead of manually calling individual scripts:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "install.ps1")
```

The installer asks where to place local dependencies, checks Python/Node/Git, installs the Codex skill, can install GUI dependencies and optional upstream tools, then runs Ziniao setup. For unattended full installs, use `-NonInteractive -InstallLazadaDeps -InstallOptionalTools -InstallMissingRuntimes -LocalToolsRoot "<D-or-E-drive-path>"`.

Interpret `diagnose-local.ps1` results directly:

- `can_sync_ziniao_shops=true`: the package can scan local Ziniao and auto-generate `shops.json`; missing `shops.json` is not a blocker.
- `detected_ziniao_shops_count`: number of stores detected from this computer's local Ziniao browser list.
- `ziniao_shops_unavailable`: local shop cache is empty and Ziniao scanning failed. Run `setup-ziniao.ps1`; it launches/foregrounds Ziniao, waits for local login, and scans local store browsers into `shops.json`.
- `python_missing`: install Python 3 first.
- `ziniao_path_not_detected`: open Ziniao manually or fill `ziniao.local.json` `client_path`.
- `ziniao_webdriver_not_reachable`: Shopee/TikTok precision opening and local store scanning will fail until local Ziniao is open/logged in and the webdriver/API port is reachable. Run `setup-ziniao.ps1` first.
- `pywinauto_missing_for_lazada`: run `install-python-deps.ps1` before Lazada precision opening.
- If `ready_for_shopee_tiktok=true`, Shopee/TikTok store matching should work; backend access still depends on local seller login state.
- If `ready_for_lazada=true`, Lazada GUI automation prerequisites are present; visual/window differences can still require manual help.

If the package does not fit this employee computer, read and follow:

```text
<package_root>\本机适配修复提示词.txt
```

Use that prompt as the repair boundary. Repair only this local `ziniao-ops` package and local configuration. Do not modify unrelated private projects, do not fetch credentials, and do not bypass login or verification.

## Login Boundary

Hard rules:

- The employee computer must already be logged in to the target seller account.
- Precision opening requires a Windows desktop with Ziniao installed and logged in.
- Never attempt to bypass login, reuse owner credentials, copy browser session data, store passwords, handle verification codes, or automate 2FA.
- `open-shop.ps1` only starts the local store-opening flow through Ziniao or an explicit URL mode. It cannot prove the backend was entered.
- If the browser lands on a login page, stop and tell the employee to log in manually on this computer, then rerun the same command.
- Do not claim “the store backend is opened successfully” unless the user confirms the page is inside the seller backend. Prefer: “已在本机发起店铺打开；如果跳到登录页，请本机手动登录后重试。”

## Quick Workflow

1. Confirm the local package exists:

```powershell
Test-Path (Join-Path $ZiniaoOpsHome "open-shop.ps1")
```

2. For first-run or unclear login state, prepare Ziniao first:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "setup-ziniao.ps1")
```

If it returns `ziniao_login_required`, tell the employee: “紫鸟已经打开并置顶，请在紫鸟窗口完成登录；完成后重新运行 setup-ziniao 或重新说同一句开店命令。”

3. For normal employee requests, prefer `operate-store.ps1` over raw `open-store.ps1`. It resolves the user's intent, creates a read-only task file, opens the first relevant view, and returns concrete next-step instructions so the user does not need to know which seller-backend button to click.

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "operate-store.ps1") "<店铺关键词>" "<用户原话>"
```

Use `open-store.ps1` only when the user explicitly wants just opening or when debugging the opener. It first tries to reuse the current Ziniao window or already-open store window. If the current Ziniao account list is already showing the target store row, the GUI path should click that row's start/switch button directly. Only when quick reuse fails should it prepare Ziniao, wait for the employee to complete local Ziniao login if needed, scan the local browser list, then automatically continue into `open-shop.ps1`. The employee should not need to say “continue” after logging in.

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "open-store.ps1") "<店铺关键词>" -View overview
```

Use `open-shop.ps1` directly only for diagnostics, dry-runs, list refreshes, or when Ziniao readiness has already been confirmed in the same workflow.

Common user phrases should map to the same command:

- “打开/开一下/进入/帮我看 <店铺关键词>” -> `home`
- “全部数据/全部情况/整体情况/总览/概览” -> `overview`
- “订单/商品/库存/财务/客服/评价/物流/售后/退款” -> matching generic view
- “打开广告页/广告后台/投流后台” -> `ads`
- “营销中心/优惠券/活动/直播/联盟” -> matching marketing view
- “打开数据中心/商业分析/生意参谋/运营数据” -> `business` for Shopee, `dashboard` for Lazada
- “打开 Compass/罗盘/数据罗盘” -> `compass`
- “打开全效宝/Max 全站推广/SMAX/smax” -> `smax`
- “页面有广告弹窗/教程弹窗/公告挡住了” -> use visual popup handling rules after the store opens

Default precision methods:

- Current-window quick path: reuse the already-open Ziniao account list or store window first. Do not run setup or wait for login when the target store row is already visible and can be confirmed.
- Shopee / TikTok: local Ziniao webdriver/API (`ziniao_webdriver`) after the current-window quick path.
- Lazada: local Ziniao GUI (`ziniao_gui`) after the current-window quick path.
- If Ziniao webdriver/API cannot return `browserList` because of login state or local API issues, fall back to the generic Ziniao GUI opener. It should search the visible Ziniao account list by the user's keyword, confirm the target row text, and click only that row's start/switch button.
- Store list source: local Ziniao browser list. Employees can only open stores visible in their own local Ziniao account.
- Ziniao path is not fixed. The installer writes `ziniao.local.json` when it can detect the executable; runtime also checks `ZINIAO_CLIENT_PATH`, `ZINIAO_PATH`, common install folders and PATH. If scanning fails, scripts try to auto-launch Ziniao and wait up to 180 seconds for the employee to log in locally.
- URL-only mode is a fallback and must be explicit with `-UrlOnly` or `-UrlFallback`.
- Force URL navigation only when explicitly needed with `-NavigateView`; otherwise use visual clicks after the store opens.
- For stores auto-detected from Ziniao, view URLs may be empty. In that case open the local store environment first, then use visual clicks to reach the requested operations module or data page. Explicit `-NavigateView` still requires a URL.
- For manually maintained stores, missing requested view URLs still fail by default. Use `-AllowHomeFallback` only when the user accepts opening home instead.
- Local command execution from `open_command` is disabled by default. Use `-AllowCommand` only when the local `shops.json` is trusted.

After the store opens, use visual interaction to reach the requested page and close blocking popups. For popup rules, read:

```text
<package_root>\references\popup-handling.md
```

For detailed user phrase to view mapping, especially non-ad requests and "全部数据", read:

```text
<package_root>\references\view-intents.md
```

For multi-step operations work such as "巡店", "日报", "店铺体检", "看这个店全部情况并汇总", or "批量巡店", read:

```text
<package_root>\references\ops-workflows.md
```

Create a read-only task plan before opening multiple modules:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\new-ops-task.ps1") -Store "<店铺关键词>" -Intent "<用户原话>" -Platform "<平台>"
```

For several stores, create a batch checklist first:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\new-ops-batch.ps1") -Store "<店铺1>","<店铺2>" -Workflow daily_check
```

Do not silently operate many stores. Show the generated checklist or summarize the store count, workflow, and first commands before proceeding.

If a workflow fails or the employee corrects the process, record a local-only learning note:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\record-ops-learning.ps1") -Kind "fix" -Store "<店铺关键词>" -Intent "<用户原话>" -Problem "<问题>" -Fix "<修复>"
```

Read local lessons before repeating a failed workflow:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\show-ops-learning.ps1")
```

4. If the user only wants to test matching:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "open-shop.ps1") "<店铺关键词>" -View orders -DryRun
```

To refresh the local store cache from Ziniao:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "open-shop.ps1") -List -RefreshZiniao
```

## View Mapping

`View` is a module intent, not just an ads shortcut. Common views include `home`, `overview`, `orders`, `products`, `inventory`, `ads`, `marketing`, `business`, `traffic`, `finance`, `chat`, `reviews`, `vouchers`, `campaigns`, `livestream`, `affiliate`, `logistics`, `returns`, `compass`, `dashboard`, `discovery`, and `smax`.

If the user says "全部数据" or "看这个店全部情况", open with `-View overview`, read visible dashboard/summary KPIs first, then drill into specific modules only when needed. Do not claim every module was checked unless you actually opened those modules.

For the full mapping and platform-specific hints, read:

```text
<package_root>\references\view-intents.md
```

## Local Data

Read local stores from:

```text
<package_root>\shops.json
```

`shops.json` is a local cache generated from this computer's Ziniao browser list. Do not require employees to fill it manually for normal use. If it is missing or empty, run `open-shop.ps1`; it will scan local Ziniao automatically. Use `-RefreshZiniao` when the employee has added/removed stores in Ziniao.

For each auto-detected shop, the cache should contain:

```json
{
  "open_method": "ziniao_webdriver",
  "ziniao_name": "紫鸟里的店铺名",
  "browser_oauth": "",
  "browser_id": ""
}
```

Use `open_method: "ziniao_gui"` for Lazada.

Treat `View` as a target hint for visual navigation unless the user explicitly asks to force URL navigation with `-NavigateView`.

For schema details, read:

```text
<package_root>\references\shops-schema.md
```

For public release positioning, external project comparisons, or future integration choices, read:

```text
<package_root>\references\external-projects.md
```

For tracked upstream repository names and update checks, read:

```text
<package_root>\references\upstreams.md
```

For exact upstream feature status and optional adapter commands, read:

```text
<package_root>\references\upstream-integration.md
```

Default route remains the built-in employee-local Ziniao opener. Use optional external adapters only when the user explicitly asks for the upstream route or when diagnosing upstream support:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\status-upstream-adapters.ps1")
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\check-upstreams.ps1")
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\sync-upstreams.ps1")
```

If the user asks to install all optional upstream tools, run:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\install-upstream-tools.ps1")
```

Do not copy code from `.upstreams` into the public repo automatically. Review license and safety first. For `auto-ziniao`, treat the mirror as reference-only unless explicit permission is granted.

For LinkFox, Seller Sprite, Amazon Reviews, creative tools, or self-improving agent questions, read:

```text
<package_root>\references\external-tools.md
```

Then check official external tool status:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\check-external-tools.ps1")
```

Do not claim closed SaaS tools are installed by this package. LinkFox tools and Seller Sprite require explicit user account/API/MCP setup. Use them as optional routes for market research, Amazon reviews, creative generation, and Amazon research, not as dependencies for local Ziniao store opening.

Use `scripts\invoke-ziniao-cli.ps1` only when the optional `ziniao` CLI is installed and the user asks for that route. Use `scripts\invoke-auto-ziniao.ps1` only when `auto-ziniao` is installed; running store flows requires explicit `-AllowExternalRunner`.

BrowserMCP and Vibe Seller are optional external routes. BrowserMCP still requires its Chrome extension and MCP client config. Vibe Seller is a full service and should not be started unless the user explicitly asks for that route and required local keys/configuration are present.

For standardized visible-data reports, use:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\new-ops-report.ps1") -Store "<店铺>" -Platform "<平台>" -View "<view>" -MetricsJson "{}"
```

If the user asks to send an operations report to Feishu/Lark, prefer an available Feishu/Lark IM tool. If using local `lark-cli`, dry-run first:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\send-ops-report-lark.ps1") -ReportPath "<report.md>" -ReceiveId "<chat-or-user-id>"
```

Only rerun with `-AllowSend` after the target chat/user is clear. Do not send reports containing passwords, verification codes, cookies, tokens, or session data.

## Feishu / lark-cli

Use `lark-cli` only to refresh or inspect shop metadata when the user asks for that. The CLI does not open stores.

If refreshing from Feishu, follow:

```text
<package_root>\references\lark-sync.md
```

If the user provides a CSV exported by Feishu/lark-cli, import it with:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\import-shops-csv.ps1") <csv-path>
```

Never store or print passwords, verification codes, browser session data, or tokens.

## Failure Handling

- Multiple matches: show candidates and ask for platform/country/more keywords.
- No match: run `open-shop.ps1 -List -RefreshZiniao`; if still missing, tell the employee this local Ziniao account does not contain that store.
- Ziniao not running or not logged in during a real open request: use `open-store.ps1`, not a separate `setup-ziniao.ps1` plus a second user prompt. It should first try current-window reuse; if that fails, it should launch/foreground Ziniao, wait for local login, scan the local browser list, and continue to open the requested store. If timeout happens, tell the employee the same command can be run again after login.
- Ziniao API login-state error after waiting: use the GUI fallback path if the user requested an actual open, not a dry-run.
- `ziniao_login_required`: Ziniao is visible but stopped on its own login page. The script raises the login window and waits for local login before failing. Do not click login or handle credentials; if it times out, ask the employee to complete login locally and rerun the same command.
- Browser opens login page: this means the employee computer is not logged in for that store. Do not assist with credentials; tell the employee to log in manually, then run the same command again.
- Precision open fails: do not silently open a normal URL. Ask whether to use `-UrlFallback`.
- URL missing for the requested view on a manually maintained shop: do not report success. Ask for the correct link, or rerun with `-AllowHomeFallback` only if the user accepts opening home.
- URL missing for an auto-detected Ziniao shop: open the local store environment, then use visual navigation to reach the requested view.
- `command_disabled`: do not bypass it. Only rerun with `-AllowCommand` if the user confirms this local `shops.json` is trusted.
- Blocking ad/tutorial popup: close or skip it visually using the safe popup rules; then continue.
- Local-machine mismatch: run `diagnose-local.ps1`, inspect only files under `$ZiniaoOpsHome`, make the smallest local adaptation, then rerun `diagnose-local.ps1` and `open-shop.ps1 "<keyword>" -View <view> -DryRun -Json`. Report changed files and remaining blockers.
