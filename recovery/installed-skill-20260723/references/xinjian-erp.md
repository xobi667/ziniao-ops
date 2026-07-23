# Xinjian ERP Workflow

Use this reference when the user asks for 心舰 ERP, xinjianerp.com, ERP 广告数据, 产品广告, 分时数据, or hourly ad performance analysis. For browser-surface selection, follow [codex-browser.md](codex-browser.md): Codex CLI and Codex IDE both use the Codex built-in Browser by default.

For 心舰 page/button memory and RPA-like "say what to do" routing, use `references/xinjian-ui-map.md` first. Query the curated `references/xinjian-ui-map.json` plus generated `references/xinjian-ui-auto-map.json` with `scripts/query-xinjian-ui-action.ps1` before taking screenshots or guessing buttons. If the target route is unclear and a debuggable browser is available, run `scripts/discover-xinjian-routes.ps1` to read real Vue Router paths and visible menus. Capture unmapped pages with `scripts/crawl-xinjian-dom-pages.ps1`, `scripts/capture-xinjian-dom-map.ps1`, or `scripts/capture-xinjian-ui-map.ps1`, then promote only generic controls and purposes into the public map.

## Default Route

Always start in the Codex built-in Browser. Open or reuse an actual 心舰 page there, navigate to the advertising analysis page, close safe blocking popups, click read-only/navigation controls such as the advertising module, platform/date tabs, or query button, verify visible advertising metric text, save a screenshot, and download an explicit export. Use the scripts below for deterministic export watching, validation, analysis, and report generation; they must not silently replace the built-in Browser with a generic browser MCP or a separate Edge/Chrome profile. For this route, report figures only when Browser evidence proves the required UI interaction and the explicit export analyzer independently returns `real_data_verified=true`. The analyzer intentionally does not pretend that it verified Browser interaction.

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\xj-open.ps1") -Json
```

Without a downloaded file, the command above and `xj-ad-hourly.ps1` return `codex_browser_handoff`; that is a routing instruction, not a failed attempt to control Browser from PowerShell. After Browser downloads the requested file, analyze it locally:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\xj-ad-hourly.ps1") -InputPath "<export.xlsx>" -StoreName "<店铺A>,<店铺B>" -Days 7 -Json
```

If the user provides an exported file:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\xinjian-erp-ad-hourly.ps1") -InputPath "<export.xlsx>" -StoreName "<店铺A>,<店铺B>" -Days 7 -Json
```

If the user is about to export from 心舰 ERP but does not want to provide the filename, wait for a new file in Downloads and analyze it automatically:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\xj-export-watch.ps1") -StoreName "<店铺A>,<店铺B>" -Days 7 -TimeoutSec 300 -Json
```

When a mapped 心舰 export/download button is run through the explicitly authorized legacy `scripts\invoke-xinjian-ui-action.ps1` route, read its `post_execute` object. Before authorization, `post_execute.rerun_after_confirmation` shows the exact rerun fields for `-Execute -AllowLegacyLocalBridge -AllowExport`; after a successful authorized export, top-level `next_action` is `wait_for_xinjian_export_or_open_download_center`. Run `wait-xinjian-export.ps1` first, then use the mapped `打开下载中心` fallback if 心舰 generates the file asynchronously.

The export watcher records its startup baseline and only considers a new or changed file. It rejects generic traffic/order tables, incomplete requested-store coverage, missing row dates, and ambiguous files. Before analysis it copies the stable source through a locked handle into a restricted private snapshot, records its SHA256, and analyzes that snapshot so the source cannot be replaced between validation and use. `-AllowDateFallback` and the lower-level `-AssumeSingleStore` are explicit diagnostic relaxations only: their corresponding verification field remains false, so the result must not be reported as verified real data.

## Explicit Legacy Browser Fallback

The local CDP/temporary Edge bridge is a legacy compatibility route, not the default browser surface. Use it only when the user explicitly asks to reuse a Ziniao/Xinjian local browser context, the Codex built-in Browser cannot complete that specific task, and the user accepts a separate manual-login browser. Never install or invoke a generic browser MCP as a substitute. The user must enter credentials and verification manually; do not read cookies, localStorage, access tokens, or passwords.

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\open-xinjian-login.ps1") -Json
```

If the requested DevTools port is already reachable, `open-xinjian-login.ps1` first scores existing 心舰 tabs on that port and reuses the best match instead of opening a duplicate tab. Logged-in business pages score above login pages; login pages are only used as manual-login handoff targets when no business page exists. Its JSON output reports `reused_existing_page`, `opened_new_tab`, `matched_page_url`, `matched_page_title`, `matched_page_id`, `matched_page_score`, `matched_page_kind`, and `next_action` so Codex can tell whether it reused or opened a page and whether the page is ready for learning/fetching.

Before opening or reusing this legacy login bridge, `open-xinjian-login.ps1` checks visible/debuggable 心舰 windows. If any 心舰 page is already open, it returns `skipped_debuggable_open = true`, `window = "existing"`, the detected `matched_page_kind`, and a `next_action` for that existing page instead of opening another browser. Use `-ForceDebuggable` only when the user explicitly wants a separate debuggable login/data-capture browser despite the already-open 心舰 window.

High-level action commands must not open this legacy bridge merely because no 心舰 page can be resolved. Normal calls should keep automatic legacy opening suppressed and return a blocker for the Codex built-in Browser route. Only after the user explicitly selects the legacy fallback and passes `-AllowLegacyLocalBridge` may `scripts/list-xinjian-page-actions.ps1` or `scripts/invoke-xinjian-ui-action.ps1` return a `login_bridge` object showing whether an existing page was reused, a debuggable page was opened, and whether the result is `business_page`, `login_page`, or `non_business_page`.

After the user confirms login is complete in that browser window, fetch the hourly endpoint through the logged-in page context and run the Excel analyzer:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\fetch-xinjian-browser-data.ps1") -Port 9339 -StoreName "<店铺A>,<店铺B>" -Days 7 -Json
```

This route first runs the UI interaction probe and saves its click evidence plus screenshot under `reports.local`, then asks the page to call the known 心舰 endpoint with `credentials: "include"` and saves the endpoint response for analysis. It must not print or persist session secrets. If the UI probe cannot verify a real advertising route, at least one safe business-control click, visible advertising metric text such as `广告花费` or `广告销售额`, and a saved screenshot, the result must not be treated as real business data even when the endpoint returns rows.

If the user explicitly says to run 心舰 through 紫鸟, the request selects the legacy local-context route. First try the already-running 紫鸟 browser CDP bridge without opening another browser. It discovers active `ziniaobrowser.exe` debug ports and fetches through a matched existing page context:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\xinjian-ziniao-bridge.ps1") -AllowLegacyLocalBridge -StoreName "<店铺A>,<店铺B>" -Days 7 -NoAutoOpen -Json
```

If the user provides a 心舰 URL, pass it through `-Url`. The bridge must first enumerate already-running debuggable browser tabs, score them against that URL, and try the best matching existing tab. Keep `-NoAutoOpen` for the normal legacy probe. If no 心舰 window exists, stop and return the blocker; only omit `-NoAutoOpen` after the user separately confirms opening a temporary Edge/Chrome legacy browser:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\xinjian-ziniao-bridge.ps1") -AllowLegacyLocalBridge -Url "https://erp.xinjianerp.com/index/home" -StoreName "<店铺A>,<店铺B>" -Days 7 -NoAutoOpen -Json
```

If the result is `manual_xinjian_login_in_ziniao_required`, 心舰 is not logged in inside that 紫鸟 browser. The user must complete 心舰 login in the opened 紫鸟 browser window; do not enter credentials or verification for them.

The bridge reports `detected_pages`, `attempts`, `runtime_status`, `auto_open`, `page_url`, and `login_state`. `app_authenticated` means the opened 心舰 page is logged in and the frontend request module was able to call the advertising endpoint. If `auto_open.ok=true` and the result is `manual_login_required`, the explicitly approved legacy browser was opened successfully but 心舰 still needs manual login there. If any 心舰 window is already open but not usable for CDP data extraction, the bridge returns `skipped_fallback_open_due_existing_window = true` and must not open a duplicate window or tab; use `-ForceOpen` only after the user explicitly asks for a separate debuggable page. If the result is `xinjian_window_detected_without_debug_port`, Codex saw a likely 心舰 window by DevTools-free window detection; that window can expose a title and sometimes the address-bar URL through Windows UIA, but it cannot be inspected or used for data extraction like a CDP page because it has no DevTools port. Mapped safe non-write visible controls may still be invoked through `invoke-xinjian-ui-action.ps1 -AllowLegacyLocalBridge` when the action catalog has a matching UIA locator. If the result is `target_browser_window_not_detected`, return to the Codex built-in Browser route; do not automatically rerun without `-NoAutoOpen`. If the result is `target_stores_not_found_in_xinjian`, do not ask the user to log in again; the current 心舰 account is authenticated but the requested store names were not found in the available shop list. Use `store_suggestions` to show nearby matches, but do not substitute a different region/store without user confirmation.

The script reads `.xlsx`, `.csv`, and `.json` exports, then groups data by store and hour. Legacy `.xls` files are not treated as supported input unless the local Python environment has a reliable reader added later. It computes ROAS, CTR, CR, CPC, ad spend, ad revenue, orders, clicks, and impressions. The best time period is selected primarily by ROAS, with orders, revenue, clicks, and CPC used as tie breakers.

The PowerShell wrapper writes both a Markdown summary and an Excel workbook by default. In JSON mode, return the path from `excel_output` as the deliverable workbook. The workbook contains:

- `最佳时段`: one best hour row per store.
- `分时明细`: all store-hour aggregates.
- `原始记录`: normalized source rows used in the calculation.
- `说明`: date window, data source, and selection logic.

Only present final ad-performance figures as real data when the JSON result has `real_data_verified: true` and `ui_interaction_verified: true`. The answer should cite the evidence from `data_source.evidence`, especially the Browser or legacy CDP page URL, input file path, UI click probe, visible metric markers, screenshot path, response path, record count, files used, and source types. If `real_data_verified` is false, do not use any generated table as a business conclusion; report the blocker from `next_action` and the relevant login/store-match fields. Window detection, title-only matches, UIA action maps, route maps, remembered buttons, Browser availability checks, and API-only calls without verified UI clicks are not real data sources.

## Known API

The frontend uses:

```text
POST /prod-api/erp/ad/data/summary-by-date_v2
```

Important parameters:

- `dateType: 1` means hourly data.
- `startTime` / `endTime` define the report window.
- `shopIds` filters stores when internal shop IDs are known.
- `currencyType` controls currency aggregation.

Without an active 心舰 ERP login, the endpoint returns a normal HTTP 200 wrapper with `code: 401` and `msg: 账号未登录`.

## Login Boundary

Do not read, copy, print, or reuse browser cookies, localStorage, access tokens, refresh tokens, or Bearer tokens. Do not enter passwords, verification codes, or solve 2FA.

If the endpoint reports `账号未登录`, continue in this order:

1. Keep the real page open in the Codex built-in Browser and tell the user to complete 心舰 login there, then rerun the same request.
2. Do not use stale local exports as a substitute for current page data unless the user explicitly provides an export path or reruns with `-AllowLocalFallback`.
3. If the user can export now, run `wait-xinjian-export.ps1` before they export so the download is analyzed automatically.
4. If the Codex built-in Browser is unavailable, report that blocker. Do not install or configure a generic browser MCP as a replacement.
5. Only if the user explicitly asks for the legacy local-context workaround and accepts a separate manual-login browser, use `open-xinjian-login.ps1` plus `fetch-xinjian-browser-data.ps1`.
6. Do not use system Chrome, Ziniao GUI, coordinate clicks, or foreground browser automation unless the user explicitly accepts foreground control for this specific task.

## Report Shape

Return a table with at least:

```text
店铺 | 最佳时段 | ROAS | 广告销售额 | 广告花费 | 广告订单 | 点击 | 展示 | CTR | CR | CPC | 判断
```

Mention the data source, date window, and Excel workbook path. If the script relaxed the date filter because the export had no rows in the requested window, state that clearly.
