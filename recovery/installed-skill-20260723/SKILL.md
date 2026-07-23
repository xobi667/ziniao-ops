---
name: ziniao-ops
description: Open, operate, troubleshoot, and report on employee-local Shopee, TikTok/Tokopedia, Lazada, and Xinjian pages through the Codex built-in Browser by default, with local Ziniao discovery/opening and strict local report analysis as supporting capabilities. Use when the user asks to open a store, enter seller backend, check ads/operations/order/product/finance/review/logistics pages, handle login-page or popup blockers, run shop checks/reports, refresh the local Ziniao shop cache, diagnose Ziniao setup, or review external ecommerce tools/API routes. Triggers include 打开店铺, 店铺后台, 操作一下, 全部数据, 运营数据, 数据中心, 广告后台, Compass, Lazada dashboard, 全效宝, 巡店, 店铺体检, 日报, 发飞书, 上游同步, 电商工具, 平台API, 本机不适配.
---

# Ziniao Ops

Use this skill only for the employee-local quick-open package installed on the current computer. Do not use unrelated private projects or external business systems to open stores. This workflow opens stores on the current employee computer only. The employee's available stores come from the store browsers visible in this computer's local Ziniao account.

Full Ziniao automation is Windows-only. On macOS/Linux/WSL, use this skill only for configuration, diagnostics, CSV import, or explicit URL/manual fallback; do not claim precision Ziniao opening is supported there.

## Codex Browser Default

For website navigation, inspection, visible interaction, screenshots, downloads, and Xinjian work, use the Codex built-in Browser as the default surface. This rule is the same in Codex CLI and Codex IDE: do not detect the host in PowerShell, branch on environment variables, or hard-code a Browser plugin cache path. Read and follow the available `browser:control-in-app-browser` skill, and let the Codex Browser runtime select and manage the built-in browser for the active product surface.

Local package scripts cannot call or emulate the Codex product Browser. They may discover local Ziniao stores, open an explicitly requested isolated Ziniao environment, query sanitized action memory, watch an export, or analyze a file. When a local shortcut needs web interaction, it must return `mode = codex_browser_handoff`, `browser_surface = codex_builtin_browser`, `supported_codex_surfaces = [cli, ide]`, `requires_product_browser = true`, `legacy_bridge_started = false`, and `next_action = use_codex_builtin_browser`. Codex must then continue with Browser itself.

Do not install, configure, or select an external browser-control server as a fallback. If the built-in Browser skill is unavailable, report `codex_browser_unavailable` and stop the web-interaction portion. Do not silently launch system Edge/Chrome, open a local DevTools port, attach through CDP, or switch to foreground GUI automation.

The old local Edge/Chrome/CDP bridge is legacy-only. It may run only when the user explicitly asks for that local bridge and the shortcut is rerun with `-AllowLegacyLocalBridge`. Options such as `-ForceOpen`, `-ForceDebuggable`, `-Port`, `-NoAutoOpen`, or a bridge script path do not grant that permission by themselves.

Native Ziniao store isolation is a separate boundary. The local `ziniao` CLI or built-in opener may still be used to list, match, and launch a store profile when the user specifically needs the employee-local Ziniao environment. Do not describe that native launch as control by the Codex Browser, and do not claim that the built-in Browser inherited the Ziniao profile or seller session.

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

It caches results briefly by default. Use `-Refresh` after the employee says they just logged in. Use `-Full` only when a stronger WebDriver/diagnose probe is needed. Treat `seller_window_detected` or `xinjian_window_detected` as local page-open signals, not proof that the backend API is authenticated and not visibility into a Codex Browser tab. The detector uses local DevTools URL/title when available and falls back to Windows UIA address-bar URL plus normal browser window titles when no DevTools port exists. Use it for native Ziniao diagnostics, not as the default Browser controller.

If the employee is setting up this package for the first time, or if Ziniao login/cache readiness is unclear, run:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "setup-ziniao.ps1")
```

For native Ziniao readiness only, the local `ziniao` CLI may list stores and launch the employee's isolated store profile without foreground mouse control. Use `scripts\invoke-ziniao-cli.ps1 -AllowExternalCommand -Json list-stores` only when that native store isolation is required. It is not the default browser page-inspection surface. Once web interaction is needed, use the Codex built-in Browser unless the user explicitly requested a legacy local bridge.

For first-time installation, prefer the package installer instead of manually calling individual scripts:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "install.ps1")
```

The installer asks where to place local dependencies, checks Python/Node/Git, installs only the locally verified versions pinned in `dependencies.lock.json`, verifies the skill reference hash manifest, and can install GUI dependencies and optional upstream tools before running Ziniao setup. On Windows it also diagnoses and removes broad write ACLs from the package, local state, reports, and local configuration files; only the current user, SYSTEM, and Administrators retain full control. For unattended full installs, use `-NonInteractive -InstallLazadaDeps -InstallOptionalTools -InstallMissingRuntimes -LocalToolsRoot "<D-or-E-drive-path>"`.

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

For 心舰/Xinjian work, use the Codex built-in Browser first. The short commands are local handoff and analysis helpers; they do not control the built-in Browser. Without `-AllowLegacyLocalBridge`, `xj-open.ps1` and browser-dependent `xj-ad-hourly.ps1` return the stable Browser handoff and do not start Edge, Chrome, or CDP:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\xj-status.ps1") -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\xj-open.ps1") -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\xj-ad-hourly.ps1") -StoreName "<店铺1>,<店铺2>" -Days 7 -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\xj-ad-hourly.ps1") -InputPath "<Browser 下载的导出文件>" -StoreName "<店铺1>,<店铺2>" -Days 7 -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\xj-export-watch.ps1") -StoreName "<店铺1>,<店铺2>" -Days 7 -Json
```

Use `query-xinjian-ui-action.ps1` as read-only action memory when Browser needs route, label, or safety guidance. Perform the actual page interaction with Browser; do not hand an in-app Browser tab to the local CDP/UIA invoker. Only report figures when Browser evidence proves a real advertising page route, at least one clicked read-only business control, visible advertising metric text such as `广告花费` / `广告销售额`, and a saved screenshot, while the explicit downloaded export independently passes the local analyzer's store/date/schema checks.

1. Confirm the local package exists:

```powershell
Test-Path (Join-Path $ZiniaoOpsHome "open-shop.ps1")
```

2. For first-run or unclear login state, prepare Ziniao first:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "setup-ziniao.ps1")
```

If it reports a Ziniao login-state error, tell the employee to open/log in to Ziniao manually and rerun the same command. Use `setup-ziniao.ps1 -AllowGuiMouse` only if the employee accepts foreground window/mouse control.

3. For normal web requests, use the Codex built-in Browser for screenshots, URL/title/text inspection, visible clicks, and read-only page work. Use the local `ziniao` CLI only when the request requires listing or launching a native employee-local Ziniao store profile:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\invoke-ziniao-cli.ps1") -AllowExternalCommand -Json list-stores
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\invoke-ziniao-cli.ps1") -AllowExternalCommand -Json open-store "<store-id>"
```

If native Ziniao isolation is not required, do not run this CLI route merely because it is installed. If native store discovery is required and the CLI is missing or cannot list the target store, use `operate-store.ps1` only for the local store plan/open preparation, then continue web interaction with Browser when a Browser-accessible page is available.

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
- Codex built-in Browser is the default route for web pages in both Codex CLI and Codex IDE. Use its visible navigation, inspection, interaction, screenshot, and download capabilities.
- `ziniao` CLI is a native store-isolation helper, not the default web inspector. Use `list-stores` and `open-store <store-id>` only when the requested seller context must be launched from the employee's local Ziniao account.
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

Treat the result as a capability map, not an installation command. Official APIs, paid SaaS tools, browser extensions, external services, and marketplace research tools require explicit user-owned account setup. Never upload local seller data to these tools by default.

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
When an exact remembered action is known from `references\xinjian-ui-rpa-command-inventory.json`, pass `-ActionId "<catalog action id>"` to query or invoke. Exact action-id routing bypasses fuzzy ranking and rejects mismatched route URLs before execution.
For page-name intents such as `打开下载中心`, the query layer synthesizes a safe page navigation action from the catalog page route so it does not confuse a page name with a row-level operation button. After changing query/routing logic, run:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\test-xinjian-rpa-routing.ps1") -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\test-xinjian-row-context-inference.ps1") -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\test-xinjian-row-context-follow-up.ps1") -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\test-xinjian-table-column-read-planning.ps1") -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\test-xinjian-export-action-planning.ps1") -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\test-xinjian-write-action-planning.ps1") -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\test-xinjian-rpa-command-inventory.ps1") -Json
```

The next live exercise and coverage commands are legacy local-CDP diagnostics, not Codex Browser commands. Run them only after the user explicitly requests that local diagnostic route, and pass `-AllowLegacyLocalBridge` on every command that opens, scans, or executes against a local CDP page. Without that authorization they return `mode=codex_browser_handoff`, perform no CDP/UIA probe, and exit 2. Offline `-DryRun` and `-UseExistingCaptures` modes remain available without legacy authorization.

To prove, within that explicitly authorized legacy route, that remembered safe route-scoped controls still click through CDP instead of only existing in the static map, run the safe action exerciser in batches:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\exercise-xinjian-safe-actions.ps1") -Port 9339 -MaxActions 50 -AllowLegacyLocalBridge -WritePublicReport -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\exercise-xinjian-safe-actions.ps1") -Port 9339 -RetryFailed -AllowLegacyLocalBridge -WritePublicReport -Json
```

It opens temporary CDP tabs and executes only route-scoped `safe_execute_allowed` controls. It excludes read-only table-column memory, confirmation-required write/export actions, row actions without row context, account menus by default, and no-route UIA globals. The sanitized public report is `references\xinjian-ui-action-exercise-report.json` / `.md`; local per-run state stays under `.ziniao-ops`.

To prove that explicitly authorized legacy local pages have no unremembered visible controls, run the live audit with the gate. The saved-capture form is offline and does not probe CDP, so it intentionally does not need the gate:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\audit-xinjian-live-button-coverage.ps1") -Port 9339 -AllowLegacyLocalBridge -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\audit-xinjian-live-button-coverage.ps1") -UseExistingCaptures -Json
```

The live coverage report is `references\xinjian-ui-live-button-coverage.json` / `.md`. It compares sanitized live DOM controls against the unified catalog and filters non-business chrome such as global sidebars, user menus, theme drawers, pagination, vendor watermarks, and table operation headers.

To answer "还缺什么" from saved evidence without opening a browser, run:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\report-xinjian-rpa-readiness.ps1") -Json
```

It writes `references\xinjian-ui-rpa-readiness.json` / `.md` and checks catalog quality, exact command inventory, live button coverage, safe action exercise proof, and remaining non-default boundaries such as business no-access pages, confirmation-required write/export actions, and row-context actions. Read-only table-column memory is tracked separately as non-gap readable column memory. Known terminal pages such as `/index/noaccess` are tracked separately as non-gap restricted pages, not missing button memory.
Read `execution_guard_plans` before answering "还缺什么": write/export/row-context counts there mean those actions have machine-readable confirmation or row-selection follow-up plans, so they are controlled execution boundaries rather than missing button memory.

For normal Codex Browser work, take the current visible Browser URL and query static action memory without scanning local windows. This returns the remembered action purpose, safety mode, and locator strategy while Browser remains the executor:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\query-xinjian-ui-action.ps1") -Url "<Codex Browser 当前心舰URL>" -Intent "<用户要做什么>" -Json
```

Only for an explicitly authorized legacy local bridge, list actions from visible/debuggable local windows with the gate. The result includes `rpa_command_mode`, exact `rpa_commands`, `current_url`, `current_title`, `resolved_port`, `page_kind`, `command_inventory`, and `next_action`; login/no-access pages return those fields even when no actions are listed:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\list-xinjian-page-actions.ps1") -AllowLegacyLocalBridge -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\list-xinjian-page-actions.ps1") -Intent "<用户要做什么>" -AllowLegacyLocalBridge -Json
```

When multiple local 心舰 windows are open in that authorized legacy route, URL resolution prefers logged-in business pages over login/restricted pages, even if the login page is the foreground debuggable window. Foreground and intent scoring are used only after business-page candidates are isolated. Passing `-Port` still pins diagnostics to that explicit port.

These CDP/UIA action commands are legacy local-runtime tools; they do not see or control a Codex built-in Browser tab. Do not use them as the default Browser backend. For Browser work, query the static action memory read-only and perform the actual action with Browser. Only use commands that scan local Chrome/Edge/Ziniao DevTools ports after the user explicitly requests the legacy local bridge; otherwise keep automatic login-bridge opening suppressed.

Before broad learning passes, audit global action memory quality so the next crawl targets weak pages instead of repeating strong pages:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\report-xinjian-action-memory.ps1") -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\learn-xinjian-weak-pages.ps1") -DryRun -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\learn-xinjian-weak-pages.ps1") -MaxPages 5 -AllowLegacyLocalBridge -Json
```

Use `learn-xinjian-weak-pages.ps1` to plan a bounded batch of high-risk pages from the audit report. Its `-DryRun` mode is offline: it reads only public action memory and local attempt state, so it intentionally does not require legacy authorization. Actual learning scans local CDP pages and is legacy-only; after the user explicitly authorizes that route, rerun with `-AllowLegacyLocalBridge`. The script passes that gate to every current-page learner it starts. It records local attempt state under `.ziniao-ops\xinjian-weak-page-learn-state.json` and skips recently attempted pages by default; pass `-RetryAttempted` to revisit them. If the audit has no weak pages, dry-run returns `ok=true` with `next_action = no_weak_pages_found`.

Dynamic source coverage is page-level, not only action-level. Overlay/dialog/row-action generators keep sanitized page entries even when a safe probe found no public dynamic controls, using `probe_ran_no_public_overlay_actions`, `probe_ran_no_public_dialog_actions`, or `probe_ran_no_public_row_actions` in `evidence.coverage_result`. Treat those entries as valid coverage evidence during audits so the workflow does not repeatedly relearn pages that were already checked and genuinely had no promotable dynamic buttons. Low-action app-shell pages are not weak when their only remembered controls are generic shell actions and all dynamic probes have covered the page; restricted/no-access pages are tracked as restricted instead of learnable weak pages.

If the current page is missing from memory or looks weakly mapped, learn it in one safe pass before guessing. This captures DOM controls, dropdown/select/date overlays, safe dialog/drawer controls, and table row action labels/operation-column action words, then regenerates the public maps and unified action catalog. The learner validates that every capture's `matched_page.url` route matches the target route; if a capture lands on a different page, generation is skipped so wrong-page controls are not promoted:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\learn-xinjian-current-page.ps1") -AllowLegacyLocalBridge -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\learn-xinjian-current-page.ps1") -Intent "<用户要做什么>" -AllowLegacyLocalBridge -Json
```

The current-page learner is a legacy local-CDP diagnostic. It auto-selects a reachable debuggable 心舰 port and returns top-level `current_url`, `current_title`, `resolved_port`, and `page_kind` only after explicit `-AllowLegacyLocalBridge` authorization. Its ordinary `-DryRun` still resolves the current local page and CDP port, so the gate remains required. `-GenerateOnly` is the offline exception: it only regenerates maps/catalog from saved sanitized captures and performs no CDP/UIA probe. Without the gate, every non-`GenerateOnly` run returns the standard Codex Browser handoff before local detection. If an authorized run only sees login or restricted 心舰 pages, it stops instead of learning the wrong page.

To learn every currently debuggable 心舰 page already open in Chrome/Edge/Ziniao, use the batch learner. It enumerates already open reachable DevTools pages, de-duplicates by route, captures each page with the safe current-page learner, then regenerates maps/catalog once. It does not open new browser windows or tabs; `-Port` only pins scanning to an existing debug port:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\learn-xinjian-open-pages.ps1") -AllowLegacyLocalBridge -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\learn-xinjian-open-pages.ps1") -MaxPages 5 -AllowLegacyLocalBridge -Json
```

The batch learner passes `-AllowLegacyLocalBridge` to every current-page learner. A `-DryRun` without explicit `-Url` values still enumerates local DevTools pages and therefore requires the gate. The only ungated batch dry-run is an explicit-URL plan such as `-Url "https://erp.xinjianerp.com/index/home" -DryRun`, which does not inspect local windows or ports.

For a full compact audit of remembered 心舰 pages/actions, regenerate and inspect the merged action catalog:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\generate-xinjian-ui-action-catalog.ps1") -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\generate-xinjian-rpa-command-inventory.ps1") -Json
```

`references\xinjian-ui-action-catalog.md` is the human-readable action table. `references\xinjian-ui-action-catalog.json` is the machine-readable merged index with context, safety mode, source map, locator strategy, locator metadata, and audit lists for manual-review or map-only actions. `references\xinjian-ui-rpa-command-inventory.json` maps every action to exact query, dry-run, safe execute, row-context, or confirmation commands keyed by `action_id`.

For an explicitly authorized legacy local-runtime action, the action invoker can turn a mapped intent into a safe RPA-style plan. It dry-runs by default and reports the exact matched action, safety gate, locator strategy, `execution_backend`, and top-level `current_url`, `current_title`, `resolved_port`, and `page_kind`. It is not the Codex Browser executor. Every legacy-local invocation must include `-AllowLegacyLocalBridge`; add `-Execute` only for safe non-write legacy actions. Add `-AllowWrite` or `-AllowExport` only after the employee explicitly confirms that exact write/export operation:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\invoke-xinjian-ui-action.ps1") -Intent "<用户要做什么>" -AllowLegacyLocalBridge -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\invoke-xinjian-ui-action.ps1") -ActionId "<catalog action id>" -Url "<当前心舰URL>" -AllowLegacyLocalBridge -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\invoke-xinjian-ui-action.ps1") -Intent "<安全动作>" -Execute -AllowLegacyLocalBridge -Json
```

`-Url` is optional for the legacy local invoker. When omitted, it may detect visible/debuggable local 心舰 windows, but when execution needs a browser page and `-AllowLegacyLocalBridge` is absent it returns `codex_browser_handoff` and must not open the manual login bridge. Only an explicit `-AllowLegacyLocalBridge` permits that local bridge to open; `-NoAutoOpenLogin` can still suppress it. This behavior does not apply to Codex Browser. Do not call the invoker for a built-in Browser tab; use `query-xinjian-ui-action.ps1` for read-only planning and let Browser perform the action. For an authorized legacy run, pass `-Url "<当前心舰URL>"` to override local detection and retain all row/write/export confirmation boundaries. Row-level actions must not click the first row by default; pass `-RowIndex <1-based row number>` / `-RowText "<visible row text>"`, or write the row target directly in the intent such as `第1行编辑`, `第一行详情`, or `包含 xxx 的行编辑`. Explicit `-RowIndex` / `-RowText` override inferred row context. Write/export row actions still require `-AllowWrite` or `-AllowExport`.

When a row-level action is matched but row context is missing, the invoker returns `row_context_follow_up.kind = row_context_required_follow_up`. Use `row_context_follow_up.rerun_with_row_index` or `row_context_follow_up.rerun_with_row_text` as the machine-readable next step; those legacy rerun fields preserve `allow_legacy_local_bridge=true`. Do not guess or click the first row. If `additional_confirmation_required` is `allow_write` or `allow_export`, keep the write/export confirmation boundary after the row is selected.

For confirmation-required export/download actions, the invoker returns a machine-readable `post_execute` object. Before confirmation it contains `rerun_after_confirmation` with `execute=true`, `allow_legacy_local_bridge=true`, and `allow_export=true`; after an authorized export execution succeeds, top-level `next_action` becomes `wait_for_xinjian_export_or_open_download_center`. Use `scripts\wait-xinjian-export.ps1` first to watch Downloads and analyze the file when applicable. If 心舰 creates an async report instead of a direct browser download, use the fallback `打开下载中心` action from `post_execute.after_success.fallback`.

For confirmation-required write/delete/save/submit actions, the invoker also returns `post_execute`. Before confirmation it contains `rerun_after_confirmation` with `execute=true`, `allow_legacy_local_bridge=true`, and `allow_write=true`; after an authorized write execution succeeds, top-level `next_action` becomes `verify_xinjian_page_state_after_write`. Verify by running `scripts\list-xinjian-page-actions.ps1 -AllowLegacyLocalBridge` on the current legacy page first; if the confirmed write changed the visible dialog, drawer, or page state, refresh memory with `scripts\learn-xinjian-current-page.ps1 -AllowLegacyLocalBridge`.

Within an explicitly authorized legacy run, if no debuggable CDP port is resolved but the matching already-open 心舰 window has a UIA-mapped safe non-write control, the invoker reports `execution_backend = "uia"` and can run it with `-Execute -AllowLegacyLocalBridge` through Windows UI Automation without moving the mouse or opening another browser. Write/export actions, row-context actions, and unknown-safety actions remain blocked without explicit confirmation and a controllable route. Read-only table-column memory needs a debuggable CDP route because it reads visible DOM table cells instead of clicking UIA controls.

Observed table metric/header entries such as `ROAS`, `广告花费`, and `转化率` are remembered as read-only `table_column` actions. They must not be clicked as buttons. In an explicitly authorized legacy run with a debuggable local 心舰 page, `invoke-xinjian-ui-action.ps1 -Intent "<字段名>" -Execute -AllowLegacyLocalBridge -Json` reads the visible values under that remembered column without clicking, writing, exporting, or reading cookies/tokens/storage. Pass `-RowIndex <1-based row number>` / `-RowText "<visible row text>"`, or include a clear row phrase in the intent such as `第1行广告花费` or `包含 xxx 的行ROAS`, to restrict the visible column read to that row.

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

Then use the Codex built-in Browser real-page workflow first. Browser must open or reuse an actual 心舰 page, navigate to the advertising analysis page, close safe blocking popups, click read-only/navigation controls such as the advertising module, platform/date tabs, or query button, verify visible advertising metric text, save a screenshot, and download an explicit export. Analyze that file locally with `xj-ad-hourly.ps1 -InputPath`. Only report figures when the Browser evidence and the analyzer's `real_data_verified = true` result both succeed. "No mouse" means the physical mouse is not hijacked; it does not mean skipping real page navigation or real button/page interaction.

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\xj-ad-hourly.ps1") -InputPath "<Browser 下载的导出文件>" -StoreName "<店铺1>,<店铺2>" -Days 7 -Json
```

The workflow writes a Markdown summary and an Excel workbook. Treat the `excel_output` path in JSON output as the main deliverable for requests that ask for a table or Excel file.
For the built-in Browser route, only report final figures when Browser supplies the required visible-page evidence and the explicit export analysis returns top-level `real_data_verified = true`. The local analyzer does not certify Browser interaction and must not be given a trust switch that merely asserts it. For an explicitly authorized legacy local bridge, retain the stricter command-level requirement that both `real_data_verified = true` and `ui_interaction_verified = true`. Include or summarize the page URL, safe visible click, visible metric markers, screenshot, record count, files used, and source types. Window detection, title-only matches, action catalogs, route maps, button memory, browser availability checks, and API-only calls without verified UI interaction are never data sources by themselves.

If the browser fetch returns `manual_login_required`, a real 心舰 page was opened or found but is not logged in. Tell the employee to complete login in that page and rerun the same command. Do not use stale local exports as a substitute unless the user explicitly provides an export path or the command is rerun with `-AllowLocalFallback`.

If the employee is ready to export from 心舰 ERP, run the download handoff before they export:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\wait-xinjian-export.ps1") -StoreName "<店铺1>,<店铺2>" -Days 7 -TimeoutSec 300 -Json
```

The watcher must start before the export. It accepts only new or changed files with explicit advertising-field evidence, complete requested-store matches, and verified row dates; it then analyzes a restricted SHA256-recorded snapshot rather than rereading the mutable download path. Never treat `-AllowDateFallback` or the lower-level `-AssumeSingleStore` as verification: those switches permit diagnostic analysis only, and `date_filter_verified` or `store_filter_verified` remains false.

If the employee explicitly rejects or cannot use the built-in Browser and separately authorizes the legacy local bridge, `xj-open.ps1 -AllowLegacyLocalBridge` may start the isolated manual login bridge. It starts a temporary Edge/Chrome profile and local DevTools port; the employee must enter credentials and verification manually. Do not read cookies, localStorage, access tokens, or passwords. Browser unavailability alone is not permission to run this fallback.

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\xj-open.ps1") -AllowLegacyLocalBridge -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\fetch-xinjian-browser-data.ps1") -Port 9339 -StoreName "<店铺1>,<店铺2>" -Days 7 -Json
```

When the requested DevTools port is already reachable, `open-xinjian-login.ps1` scores existing 心舰 tabs on that port and reuses the best match instead of opening a duplicate tab. Logged-in business pages score above login pages. Read `reused_existing_page`, `opened_new_tab`, `matched_page_url`, `matched_page_title`, `matched_page_score`, `matched_page_kind`, and `next_action` from JSON before telling the employee what happened. `matched_page_kind=business_page` with `next_action=xinjian_business_page_ready` means the page can be used for learning/fetching; `login_page` means the employee still needs to log in manually.

Before opening or reusing a login bridge, `open-xinjian-login.ps1` now checks visible/debuggable 心舰 windows. If any 心舰 page is already open, it returns `skipped_debuggable_open = true`, `window = "existing"`, the detected `matched_page_kind`, and a `next_action` for that existing page instead of opening another browser. Only pass `-ForceDebuggable` when the user explicitly wants a separate debuggable login/data-capture browser despite the already-open 心舰 window.

If the employee explicitly says to run 心舰 through the legacy local 紫鸟 bridge instead of Browser, authorize that route explicitly:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\xj-ad-hourly.ps1") -AllowLegacyLocalBridge -ZiniaoOnly -StoreName "<店铺1>,<店铺2>" -Days 7 -Json
```

If the employee provides a 心舰 URL, pass it with `-Url`. The bridge should enumerate existing debuggable tabs and try the best URL match before it opens any new page:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\xj-ad-hourly.ps1") -AllowLegacyLocalBridge -ZiniaoOnly -Url "https://erp.xinjianerp.com/index/home" -StoreName "<店铺1>,<店铺2>" -Days 7 -Json
```

If it returns `manual_xinjian_login_in_ziniao_required`, 心舰 is open in a 紫鸟 browser but not logged in; the employee must manually complete 心舰 login there.

Within an explicitly authorized legacy run, the local bridge may open a controllable Edge/Chrome page and continue detection. If that page is not logged in, the employee must manually complete login there and rerun the same authorized command. `-ForceOpen`, `-NoAutoOpen`, `-Port`, or `-ZiniaoOnly` never replace the required `-AllowLegacyLocalBridge` gate.

Use `scripts\invoke-ziniao-cli.ps1` only for native local store list/open preparation when that Ziniao isolation is required. Use Codex Browser for web inspection. The CLI wrapper still refuses secret-like arguments and long-running commands unless explicitly allowed. Use `scripts\invoke-auto-ziniao.ps1` only when `auto-ziniao` is installed; running store flows requires explicit `-AllowExternalRunner`.

Do not install or select external browser-control routes for normal work. The supported default is the Codex built-in Browser. Vibe Seller remains a separate full service and must not be started unless the user explicitly asks for that service and its required local configuration is present.

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
