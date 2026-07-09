---
name: ziniao-ops
description: Open, operate, troubleshoot, and report on employee-local Shopee, TikTok/Tokopedia, and Lazada seller backends through the local ziniao CLI first, with built-in PowerShell/WebDriver fallback, visual navigation, read-only operation plans, optional lark-cli/Feishu reporting, and optional ecommerce tool/API reference maps. Use when the user asks to open a store, enter seller backend, check ads/operations/order/product/finance/review/logistics pages, handle login-page or popup blockers, run shop checks/reports, refresh the local Ziniao shop cache, diagnose Ziniao setup, or review external ecommerce tools/API routes. Triggers include 打开店铺, 店铺后台, 操作一下, 全部数据, 运营数据, 数据中心, 广告后台, Compass, Lazada dashboard, 全效宝, 巡店, 店铺体检, 日报, 发飞书, 上游同步, 电商工具, 平台API, 本机不适配.
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

For lightweight current-state detection that does not move the mouse, navigate, or read cookies/tokens, run:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\get-runtime-status.ps1") -Json
```

It caches results briefly by default. Use `-Refresh` after the employee says they just logged in. Use `-Full` only when a stronger WebDriver/diagnose probe is needed. Treat `seller_window_detected` or `xinjian_window_detected` as page-open signals, not proof that the backend API is authenticated. The detector uses DevTools URL/title when available and falls back to Windows UIA address-bar URL plus normal browser window titles when no DevTools port exists; title-only matches are useful for not missing an already-open window. Non-DevTools windows cannot be inspected or fetched through CDP, but mapped safe non-write 心舰 controls can be invoked through Windows UI Automation when the action catalog has a matching UIA locator. Default workflows should run detection and safe non-mouse recovery automatically; do not ask the employee to run these checks manually.

If the employee is setting up this package for the first time, or if Ziniao login/cache readiness is unclear, run:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "setup-ziniao.ps1")
```

By default, try the local `ziniao` CLI first because it can list/open stores and inspect pages without foreground mouse control. Use `scripts\invoke-ziniao-cli.ps1 -AllowExternalCommand -Json list-stores` as the first readiness check when the CLI is installed. If the CLI is missing or returns a business error such as `success:false` / login-state failure, fall back to `setup-ziniao.ps1` for the built-in non-mouse WebDriver/API diagnostic. If foreground GUI/login handoff is acceptable, explicitly add `-AllowGuiMouse`; it must still never enter credentials or solve verification.

For first-time installation, prefer the package installer instead of manually calling individual scripts:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "install.ps1")
```

The installer asks where to place local dependencies, checks Python/Node/Git, installs the Codex skill, can install GUI dependencies and optional upstream tools, then runs Ziniao setup. For unattended full installs, use `-NonInteractive -InstallLazadaDeps -InstallOptionalTools -InstallMissingRuntimes -LocalToolsRoot "<D-or-E-drive-path>"`.

Interpret `diagnose-local.ps1` results directly:

- `can_sync_ziniao_shops=true`: the package can scan local Ziniao and auto-generate `shops.json`; missing `shops.json` is not a blocker.
- `detected_ziniao_shops_count`: number of stores detected from this computer's local Ziniao browser list.
- `ziniao_shops_unavailable`: local shop cache is empty and Ziniao scanning failed. Run `setup-ziniao.ps1` for the non-mouse WebDriver/API check. If diagnosis shows login-state failure, ask the employee to open/log in to Ziniao manually; only use `setup-ziniao.ps1 -AllowGuiMouse` when foreground GUI/mouse control is acceptable.
- `python_missing`: install Python 3 first.
- `ziniao_path_not_detected`: open Ziniao manually or fill `ziniao.local.json` `client_path`.
- `ziniao_webdriver_not_reachable`: Shopee/TikTok precision opening and local store scanning will fail until local Ziniao is open/logged in and the webdriver/API port is reachable. Run `setup-ziniao.ps1` first; add `-AllowGuiMouse` only after the employee accepts foreground control.
- `ziniao_webdriver_auth_fields_missing`: Ziniao WebDriver is reachable but this local build requires company/username/password fields for WebDriver calls. Do not ask the employee to paste values into chat. Tell them to configure `ziniao.auth.local.json` on this computer from `ziniao.auth.local.example.json`, or set `ZINIAO_WEBDRIVER_COMPANY`, `ZINIAO_WEBDRIVER_USERNAME`, and `ZINIAO_WEBDRIVER_PASSWORD`; diagnostics may only report field presence.
- `ziniao_webdriver_invalid_session`: Ziniao WebDriver is reachable but returns errors such as `参数不能为空` even after required local auth fields are present. Treat this as an invalid/stale WebDriver session or unusable isolated profile, not a normal wait-for-login state. Run `setup-ziniao.ps1 -ResetStaleWebDriver`; if it reports the WebDriver user data directory is in use, exit the normal Ziniao window/tray before retrying. Use `-AllowGuiMouse` only when the employee accepts foreground control.
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
- Some local Ziniao WebDriver builds require employee-owned auth fields on every local WebDriver request. Codex must never receive, print, or edit those values. The employee may configure them locally through ignored files or environment variables; Codex may only check whether the fields are present.
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

If it reports a Ziniao login-state error, tell the employee to open/log in to Ziniao manually and rerun the same command. Use `setup-ziniao.ps1 -AllowGuiMouse` only if the employee accepts foreground window/mouse control.

3. For normal employee requests, prefer the local `ziniao` CLI route first when it is installed. It is the default non-mouse route for listing stores, opening a store, taking snapshots/screenshots, reading URL/title/text, clicking by selector, and running read-only page inspection.

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\invoke-ziniao-cli.ps1") -AllowExternalCommand -Json list-stores
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\invoke-ziniao-cli.ps1") -AllowExternalCommand -Json open-store "<store-id>"
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\invoke-ziniao-cli.ps1") -AllowExternalCommand -Json --store "<store-id>" snapshot
```

If the CLI is missing, cannot list the target store, or returns a login-state/business error, fall back to `operate-store.ps1` for normal work. It resolves the user's intent, creates a read-only task file, opens the first relevant view, and returns concrete next-step instructions so the user does not need to know which seller-backend button to click.

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "operate-store.ps1") "<店铺关键词>" "<用户原话>"
```

Use `open-store.ps1` only when the user explicitly wants just opening or when debugging the built-in opener. Its default path must use non-mouse WebDriver/API opening. Only when the employee explicitly accepts foreground GUI control and the command includes `-AllowGuiMouse` may it focus Ziniao, search visible store rows, or click the target row's 启动/切换 button. With `-AllowGuiMouse`, `open-store.ps1` goes directly to the built-in opener instead of running setup/sync first, so a local empty shop cache does not block the basic open action.

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

- Default opening must avoid foreground mouse/keyboard automation. Do not use the current-window GUI quick path, pywinauto GUI search, coordinate clicks, or Lazada GUI opening unless the employee explicitly accepts foreground GUI control and the command includes `-AllowGuiMouse`.
- `ziniao` CLI is the default route when installed. Use `list-stores` to get candidate stores, match the user's keyword to the CLI store id/name, then use `open-store <store-id>` and CLI inspection commands such as `snapshot`, `screenshot`, `url`, `title`, `text`, or `eval`.
- Shopee / TikTok fallback: local Ziniao webdriver/API (`ziniao_webdriver`) remains the built-in non-mouse route when CLI is unavailable or fails.
- Lazada fallback: precision opening still requires local Ziniao GUI (`ziniao_gui`), so it must stop with `gui_mouse_confirmation_required` unless `-AllowGuiMouse` is explicitly present.
- If the CLI or Ziniao webdriver/API cannot return stores because of login state or local API issues, do not automatically fall back to GUI. Ask whether foreground GUI/mouse control is acceptable; only then rerun with `-AllowGuiMouse`.
- Store list source: local Ziniao browser list. Employees can only open stores visible in their own local Ziniao account.
- Ziniao path is not fixed. The installer writes `ziniao.local.json` when it can detect the executable; runtime also checks `ZINIAO_CLIENT_PATH`, `ZINIAO_PATH`, common install folders and PATH. If CLI scanning fails, scripts try the non-mouse WebDriver/API path and wait for an already logged-in local Ziniao session.
- Do not use CLI commands that export/import/restore cookies, tokens, sessions, or other auth material by default. Never pass secret-like arguments to the CLI.
- URL-only mode is a fallback and must be explicit with `-UrlOnly` or `-UrlFallback`.
- Force URL navigation only when explicitly needed with `-NavigateView`; otherwise use visual clicks after the store opens.
- Treat basic open and page verification as separate steps. `open-store.ps1` may return `window_verified=false` after it clicked the confirmed target store row but could not prove a new backend window appeared yet. In that case say “已在本机紫鸟中发起店铺打开”, not “已进入后台”. Only claim the backend page is open after URL/title/visible page evidence confirms a seller backend.
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

Default route is the local `ziniao` CLI when installed, with the built-in employee-local Ziniao opener as fallback. Use other optional external adapters only when the user explicitly asks for the upstream route or when diagnosing upstream support:

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

For broader ecommerce capability questions such as "还缺什么", "能不能做市场研究/评论分析/物流/财务/ERP/广告优化", or "全网电商工具都安排上", read:

```text
<package_root>\references\ecommerce-capability-map.md
<package_root>\references\platform-api-roadmap.md
```

Then check official platform/API/tool status:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\check-ecommerce-tools.ps1")
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\check-ecommerce-tools.ps1") -Category official_platform_api -TimeoutSec 1 -TotalTimeoutSec 20 -MaxConcurrency 8
```

Treat the result as a capability map, not an installation command. Official APIs, paid SaaS tools, browser extensions, external MCP servers, and marketplace research tools require explicit user-owned account setup. Never upload local seller data to these tools by default.

For 心舰 ERP / Xinjian ERP advertising tasks, especially 产品广告分时数据, hourly ad performance, ROAS by hour, or requests that include `erp.xinjianerp.com`, read:

```text
<package_root>\references\xinjian-erp.md
```

For 心舰 ERP page/button memory, UI action mapping, or requests like "把按钮都记住", "别每次截图", "像 RPA 一样说什么就干什么", read:

```text
<package_root>\references\xinjian-ui-map.md
```

Then query the known map before taking screenshots or guessing:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\query-xinjian-ui-action.ps1") -Intent "<用户要做什么>" -Url "<当前心舰URL>" -Json
```

By default the query script reads `references\xinjian-ui-action-catalog.json` first, so generated read-only table-header memory is available to intent matching. If the catalog is unavailable, it falls back to the raw curated/auto/overlay/dialog/row-action maps.
For page-name intents such as `打开下载中心`, the query layer synthesizes a safe page navigation action from the catalog page route so it does not confuse a page name with a row-level operation button. After changing query/routing logic, run:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\test-xinjian-rpa-routing.ps1") -Json
```

To prove that remembered safe route-scoped controls still click through CDP instead of only existing in the static map, run the safe action exerciser in batches:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\exercise-xinjian-safe-actions.ps1") -Port 9339 -MaxActions 50 -WritePublicReport -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\exercise-xinjian-safe-actions.ps1") -Port 9339 -RetryFailed -WritePublicReport -Json
```

It opens temporary CDP tabs and executes only route-scoped `safe_execute_allowed` controls. It excludes read-only table-column memory, confirmation-required write/export actions, row actions without row context, account menus by default, and no-route UIA globals. The sanitized public report is `references\xinjian-ui-action-exercise-report.json` / `.md`; local per-run state stays under `.ziniao-ops`.

To see what the currently open page already has in memory, list the page actions first. This resolves the current 心舰 URL read-only from visible/debuggable windows, then returns every remembered action with purpose, safety mode, and locator strategy. Read top-level `current_url`, `current_title`, `resolved_port`, `page_kind`, and `next_action` first; login/no-access pages return those fields even when no actions are listed:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\list-xinjian-page-actions.ps1") -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\list-xinjian-page-actions.ps1") -Intent "<用户要做什么>" -Json
```

When multiple 心舰 windows are open, URL resolution prefers logged-in business pages over login/restricted pages, even if the login page is the foreground debuggable window. Foreground and intent scoring are used only after business-page candidates are isolated. Passing `-Port` still pins diagnostics to that explicit port.

These high-level 心舰 action commands scan reachable Chrome/Edge/Ziniao DevTools ports by default and return `resolved_port` when a debuggable tab is selected. Use `-Port` only when intentionally pinning diagnostics or execution to a specific browser port.

Before broad learning passes, audit global action memory quality so the next crawl targets weak pages instead of repeating strong pages:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\report-xinjian-action-memory.ps1") -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\learn-xinjian-weak-pages.ps1") -DryRun -Json
```

Use `learn-xinjian-weak-pages.ps1` to automatically select and learn a bounded batch of high-risk pages from the audit report. It records local attempt state under `.ziniao-ops\xinjian-weak-page-learn-state.json` and skips recently attempted pages by default so learning keeps moving forward; pass `-RetryAttempted` to revisit them. Keep `-DryRun` for planning, then rerun without it when the selected pages are acceptable. If the audit has no weak pages, dry-run returns `ok=true` with `next_action = no_weak_pages_found`.

Dynamic source coverage is page-level, not only action-level. Overlay/dialog/row-action generators keep sanitized page entries even when a safe probe found no public dynamic controls, using `probe_ran_no_public_overlay_actions`, `probe_ran_no_public_dialog_actions`, or `probe_ran_no_public_row_actions` in `evidence.coverage_result`. Treat those entries as valid coverage evidence during audits so the workflow does not repeatedly relearn pages that were already checked and genuinely had no promotable dynamic buttons. Low-action app-shell pages are not weak when their only remembered controls are generic shell actions and all dynamic probes have covered the page; restricted/no-access pages are tracked as restricted instead of learnable weak pages.

If the current page is missing from memory or looks weakly mapped, learn it in one safe pass before guessing. This captures DOM controls, dropdown/select/date overlays, safe dialog/drawer controls, and table row action labels/operation-column action words, then regenerates the public maps and unified action catalog. The learner validates that every capture's `matched_page.url` route matches the target route; if a capture lands on a different page, generation is skipped so wrong-page controls are not promoted:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\learn-xinjian-current-page.ps1") -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\learn-xinjian-current-page.ps1") -Intent "<用户要做什么>" -Json
```

The current-page learner auto-selects a reachable debuggable 心舰 port and returns top-level `current_url`, `current_title`, `resolved_port`, and `page_kind`. If it only sees login or restricted 心舰 pages, it stops with `manual_login_required_in_debuggable_xinjian_browser` instead of learning the wrong page.

To learn every currently debuggable 心舰 page already open in Chrome/Edge/Ziniao, use the batch learner. It enumerates already open reachable DevTools pages, de-duplicates by route, captures each page with the safe current-page learner, then regenerates maps/catalog once. It does not open new browser windows or tabs; `-Port` only pins scanning to an existing debug port:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\learn-xinjian-open-pages.ps1") -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\learn-xinjian-open-pages.ps1") -MaxPages 5 -Json
```

For a full compact audit of remembered 心舰 pages/actions, regenerate and inspect the merged action catalog:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\generate-xinjian-ui-action-catalog.ps1") -Json
```

`references\xinjian-ui-action-catalog.md` is the human-readable action table. `references\xinjian-ui-action-catalog.json` is the machine-readable merged index with context, safety mode, source map, locator strategy, locator metadata, and audit lists for manual-review or map-only actions.

To turn a mapped intent into a safe RPA-style action plan, use the action invoker. It dry-runs by default and reports the exact matched action, safety gate, locator strategy, `execution_backend`, and top-level `current_url`, `current_title`, `resolved_port`, and `page_kind`. Add `-Execute` only for safe non-write actions. Add `-AllowWrite` or `-AllowExport` only after the employee explicitly confirms that exact write/export operation:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\invoke-xinjian-ui-action.ps1") -Intent "<用户要做什么>" -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\invoke-xinjian-ui-action.ps1") -Intent "<安全动作>" -Execute -Json
```

`-Url` is optional for the invoker. When omitted, it detects visible/debuggable 心舰 windows read-only and scores candidate URLs against the user's intent, so commands can pick the matching already-open 心舰 page without opening duplicate windows. Pass `-Url "<当前心舰URL>"` to override detection, or `-NoAutoDetectUrl` only for diagnostics/global matching.

If no debuggable CDP port is resolved but the matching already-open 心舰 window has a UIA-mapped safe non-write control, the invoker reports `execution_backend = "uia"` and can run it with `-Execute` through Windows UI Automation without moving the mouse or opening another browser. Write/export actions, row-context actions, read-only table-column memory, and unknown-safety actions remain blocked without explicit confirmation and a controllable route.

Observed table metric/header entries such as `ROAS`, `广告花费`, and `转化率` are remembered as read-only `table_column` actions. They are used for query/planning and must not be clicked as buttons.

If the target page is unclear and a debuggable 心舰 Chrome/Edge page is available, discover real 心舰 frontend routes and visible menus before opening a new URL:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\discover-xinjian-routes.ps1") -Port 9342 -Json
```

To continue building broad page/button memory, crawl unmapped routes in small batches and regenerate the sanitized auto map:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\report-xinjian-ui-coverage.ps1") -Port 9342 -RefreshRoutes -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\crawl-xinjian-dom-pages.ps1") -Port 9342 -OnlyUnmapped -MaxPages 20 -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\generate-xinjian-ui-auto-map.ps1") -NoMergeExisting -Json
```

`references\xinjian-ui-auto-map.json` is generated from sanitized CDP DOM captures. It is broad memory, not final proof of behavior. Curated `references\xinjian-ui-map.json` takes precedence when both contain the same route.
The auto map excludes transient Element UI poppers, date-picker panels, select dropdowns, dialogs, drawers, and message boxes so dynamic controls are remembered by the overlay/dialog maps instead of being misfiled as always-visible page buttons.
The crawler records local attempt state under `.ziniao-ops\xinjian-crawl-state.json`; pass `-RetryAttempted` only when intentionally revisiting empty, restricted, redirected, or previously failed routes.

To capture dynamic dropdown/menu/select/date-panel items on a known page, use the overlay probe and regenerate the overlay map:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\capture-xinjian-overlays.ps1") -Port 9342 -Url "<心舰页面URL>" -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\generate-xinjian-ui-overlay-map.ps1") -Json
```

To expand dynamic overlay memory across known pages, crawl mapped pages in small batches. Use `-OnlyMissing` for normal progress and `-RetryAttempted` only when intentionally revisiting pages already probed:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\crawl-xinjian-overlay-pages.ps1") -Port 9342 -OnlyMissing -IncludeSelects -MaxPages 10 -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\generate-xinjian-ui-overlay-map.ps1") -Json
```

`references\xinjian-ui-overlay-map.json` supplements both curated and auto maps. The overlay probe opens panels and closes them, but must never click overlay items or submit forms. Private-looking select values are filtered at capture time.
Pages safely probed with no promotable overlay items are still retained in the overlay map as coverage evidence.

To capture buttons and fields that only appear after safe dialog/drawer openers, use the dialog probe. It may click opener buttons such as `新增`, `编辑`, `详情`, `查看`, `设置`, or `配置`, but must never click submit/confirm/write buttons inside the dialog:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\capture-xinjian-dialogs.ps1") -Port 9342 -Url "<心舰页面URL>" -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\crawl-xinjian-dialog-pages.ps1") -Port 9342 -OnlyMissing -MaxPages 10 -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\generate-xinjian-ui-dialog-map.ps1") -Json
```

`references\xinjian-ui-dialog-map.json` supplements static and overlay maps with dialog/drawer openers, dialog buttons, field labels, and placeholders. It does not store input values or private-looking text. Dialog submit/save/confirm/delete/write buttons are confirmation-required.
Pages safely probed with no promotable dialog/drawer controls are still retained in the dialog map as coverage evidence.

To capture table row-level operation buttons such as `详情`, `编辑`, `删除`, `恢复`, `设置`, or `预警设置`, use the row-action probe. It reads only table headers, row action labels, and generic action words from operation columns. It may open non-mutating row menu triggers such as `更多` or `操作`, but it must not read row cell values or click row action menu items:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\capture-xinjian-row-actions.ps1") -Port 9342 -Url "<心舰页面URL>" -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\crawl-xinjian-row-action-pages.ps1") -Port 9342 -OnlyMissing -MaxPages 10 -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\generate-xinjian-ui-row-action-map.ps1") -Json
```

`references\xinjian-ui-row-action-map.json` supplements static, overlay, and dialog maps with table row action labels and operation-column action words. Row edit/delete/export/write actions are confirmation-required.
Pages safely probed with no promotable row actions are still retained in the row-action map as coverage evidence.

If a debuggable 心舰 Chrome/Edge page is available, capture real DOM controls first:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\capture-xinjian-dom-map.ps1") -Port 9342 -Json
```

If the current 心舰 page is not debuggable or the page is still unmapped, capture it through Windows UIA read-only and promote only generic button/filter/menu knowledge into `references\xinjian-ui-map.json`:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\capture-xinjian-ui-map.ps1") -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\capture-xinjian-ui-map.ps1") -CompareCatalog -Json
```

The UIA capture filters private/noisy browser controls, pagination-only list items, close glyphs, and non-action buttons before saving observations. `-CompareCatalog` compares the visible controls against the current unified action catalog and reports matched controls plus non-navigation controls that are still missing from memory.

Then use the non-mouse data workflow first:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\xinjian-erp-ad-hourly.ps1") -StoreName "<店铺1>,<店铺2>" -Days 7 -ProbeEndpoint -Json
```

The workflow writes a Markdown summary and an Excel workbook. Treat the `excel_output` path in JSON output as the main deliverable for requests that ask for a table or Excel file.
For 心舰 ad reports, only report final figures as real data when the command returns top-level `real_data_verified = true`. Include or summarize `data_source.evidence` in the answer: page URL when captured through CDP, response path, record count, files used, and source types. If `real_data_verified = false`, do not present best-hour results as factual; report the blocker from `next_action` instead. Window detection, title-only matches, UIA action catalogs, route maps, button memory, and MCP/browser availability checks are never data sources by themselves.

If 心舰 returns `账号未登录`, do not switch to system Chrome, BrowserMCP, Ziniao GUI, coordinate clicks, or foreground automation by default. First look for a local export or ask the employee to export the required hourly product ad data. Use an in-app browser login handoff only if that browser is available; the employee must enter credentials and verification manually.

If the employee is ready to export from 心舰 ERP, run the non-mouse download handoff before they export:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\wait-xinjian-export.ps1") -StoreName "<店铺1>,<店铺2>" -Days 7 -TimeoutSec 300 -Json
```

If the employee explicitly asks to solve 心舰 login and the in-app browser is unavailable, use the isolated manual login bridge. It starts a temporary Edge/Chrome profile and local DevTools port; the employee must enter credentials and verification manually. Do not read cookies, localStorage, access tokens, or passwords.

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\open-xinjian-login.ps1") -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\fetch-xinjian-browser-data.ps1") -Port 9339 -StoreName "<店铺1>,<店铺2>" -Days 7 -Json
```

When the requested DevTools port is already reachable, `open-xinjian-login.ps1` scores existing 心舰 tabs on that port and reuses the best match instead of opening a duplicate tab. Logged-in business pages score above login pages. Read `reused_existing_page`, `opened_new_tab`, `matched_page_url`, `matched_page_title`, `matched_page_score`, `matched_page_kind`, and `next_action` from JSON before telling the employee what happened. `matched_page_kind=business_page` with `next_action=xinjian_business_page_ready` means the page can be used for learning/fetching; `login_page` means the employee still needs to log in manually.

Before opening or reusing a login bridge, `open-xinjian-login.ps1` now checks visible/debuggable 心舰 windows. If any 心舰 page is already open, it returns `skipped_debuggable_open = true`, `window = "existing"`, the detected `matched_page_kind`, and a `next_action` for that existing page instead of opening another browser. Only pass `-ForceDebuggable` when the user explicitly wants a separate debuggable login/data-capture browser despite the already-open 心舰 window.

If the employee says to run 心舰 directly through 紫鸟, use the running 紫鸟 browser bridge first:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\xinjian-ziniao-bridge.ps1") -StoreName "<店铺1>,<店铺2>" -Days 7 -Json
```

If the employee provides a 心舰 URL, pass it with `-Url`. The bridge should enumerate existing debuggable tabs and try the best URL match before it opens any new page:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\xinjian-ziniao-bridge.ps1") -Url "https://erp.xinjianerp.com/index/home" -StoreName "<店铺1>,<店铺2>" -Days 7 -Json
```

If it returns `manual_xinjian_login_in_ziniao_required`, 心舰 is open in a 紫鸟 browser but not logged in; the employee must manually complete 心舰 login there.

If no 心舰 window is found, `xinjian-ziniao-bridge.ps1` auto-opens a controllable Edge/Chrome page by default and then continues detection. If that page is not logged in, the employee must manually complete login in the opened browser; Codex should rerun the same command after login. Use `-NoAutoOpen` only for diagnostics. If any 心舰 window is already open but not usable for CDP data extraction, the bridge returns `skipped_fallback_open_due_existing_window = true` and must not open a duplicate window or tab. Use `-ForceOpen` only after the user explicitly asks for a separate debuggable page. If it returns `xinjian_window_detected_without_debug_port`, a likely 心舰 window was found by title; that title-only window cannot be inspected or used for data extraction until it is reopened through a debuggable bridge or browser profile, though safe mapped visible controls may still be invoked through the UIA fallback in `invoke-xinjian-ui-action.ps1`.

Use `scripts\invoke-ziniao-cli.ps1` by default for local store list/open/inspect commands when the optional `ziniao` CLI is installed. The wrapper still refuses secret-like arguments and long-running commands unless explicitly allowed. Use `scripts\invoke-auto-ziniao.ps1` only when `auto-ziniao` is installed; running store flows requires explicit `-AllowExternalRunner`.

BrowserMCP and Vibe Seller are optional external routes. BrowserMCP still requires its Chrome extension and MCP client config. Vibe Seller is a full service and should not be started unless the user explicitly asks for that route and required local keys/configuration are present.

For standardized visible-data reports, use:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\new-ops-report.ps1") -Store "<店铺>" -Platform "<平台>" -View "<view>" -MetricsJson "{}"
```

If the user asks to send an operations report to Feishu/Lark, prefer an available Feishu/Lark IM tool. If using local `lark-cli`, dry-run first:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\send-ops-report-lark.ps1") -ReportPath "<report.md>" -ReceiveId "<oc_chat_id>"
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\send-ops-report-lark.ps1") -ReportPath "<report.md>" -ReceiveId "<ou_open_id>" -ReceiveIdType open_id
```

Only rerun with `-AllowSend` after the target chat/user is clear. Chat IDs must start with `oc_`; direct user targets must use a Feishu open_id that starts with `ou_`. Do not send reports containing passwords, verification codes, cookies, tokens, or session data.

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
- No match: first run CLI `list-stores`; if it cannot list usable stores, run `open-shop.ps1 -List -RefreshZiniao`; if still missing, tell the employee this local Ziniao account does not contain that store.
- Ziniao not running or not logged in during a real open request: first try CLI `list-stores`; if that fails, try the built-in non-mouse webdriver/API route. Do not launch setup/login handoff or GUI fallback by default because it can focus Ziniao and interfere with the employee's mouse. Ask whether foreground GUI/mouse control is acceptable; only then rerun with `-AllowGuiMouse`.
- Do not forcibly restart or kill Ziniao during normal opening. Only pass `open-shop.ps1 -AllowRestart` or `ziniao-gui-open.py --allow-restart` when the user explicitly confirms the current Ziniao process may be restarted.
- Ziniao API login-state error after waiting: use the GUI fallback path only after the user explicitly accepts foreground GUI/mouse control with `-AllowGuiMouse`.
- Ziniao WebDriver returns `ziniao_webdriver_auth_fields_missing`: do not keep waiting and do not ask for the values. Tell the employee to create ignored local `ziniao.auth.local.json` from `ziniao.auth.local.example.json`, or set the three `ZINIAO_WEBDRIVER_*` environment variables on this computer, then rerun `setup-ziniao.ps1 -ResetStaleWebDriver`.
- Ziniao WebDriver returns `参数不能为空` / `ziniao_webdriver_invalid_session`: do not keep waiting or tell the employee that login alone will fix it. This is usually a stale WebDriver process, missing API parameter, or isolated profile problem. Run `setup-ziniao.ps1 -ResetStaleWebDriver`; if it reports user-data in use, ask the employee to exit normal Ziniao/tray and retry, or use `-AllowGuiMouse` only with explicit foreground-control acceptance.
- Ziniao login-state errors: WebDriver/API may be reachable while the local client has no valid login context. Do not click login or handle credentials. Ask the employee to complete login locally and rerun the same command; use `-AllowGuiMouse` only after explicit acceptance of foreground GUI/mouse control.
- Browser opens login page: this means the employee computer is not logged in for that store. Do not assist with credentials; tell the employee to log in manually, then run the same command again.
- Precision open fails: do not silently open a normal URL. Ask whether to use `-UrlFallback`.
- URL missing for the requested view on a manually maintained shop: do not report success. Ask for the correct link, or rerun with `-AllowHomeFallback` only if the user accepts opening home.
- URL missing for an auto-detected Ziniao shop: open the local store environment, then use visual navigation to reach the requested view.
- `command_disabled`: do not bypass it. Only rerun with `-AllowCommand` if the user confirms this local `shops.json` is trusted.
- Blocking ad/tutorial popup: close or skip it visually using the safe popup rules; then continue.
- Local-machine mismatch: run `diagnose-local.ps1`, inspect only files under `$ZiniaoOpsHome`, make the smallest local adaptation, then rerun `diagnose-local.ps1` and `open-shop.ps1 "<keyword>" -View <view> -DryRun -Json`. Report changed files and remaining blockers.
