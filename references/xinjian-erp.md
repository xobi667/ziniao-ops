# Xinjian ERP Workflow

Use this reference when the user asks for 心舰 ERP, xinjianerp.com, ERP 广告数据, 产品广告, 分时数据, or hourly ad performance analysis.

For 心舰 page/button memory and RPA-like "say what to do" routing, use `references/xinjian-ui-map.md` first. Query `references/xinjian-ui-map.json` with `scripts/query-xinjian-ui-action.ps1` before taking screenshots or guessing buttons. If the target route is unclear and a debuggable browser is available, run `scripts/discover-xinjian-routes.ps1` to read real Vue Router paths and visible menus. Capture unmapped pages with `scripts/capture-xinjian-dom-map.ps1` or `scripts/capture-xinjian-ui-map.ps1`, then promote only generic controls and purposes into the public map.

## Default Route

Always start with the non-mouse data workflow:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\xinjian-erp-ad-hourly.ps1") -ProbeEndpoint -Json
```

For a request such as "最近七天 <店铺A> / <店铺B> 产品广告分时数据", use:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\xinjian-erp-ad-hourly.ps1") -StoreName "<店铺A>,<店铺B>" -Days 7 -ProbeEndpoint -Json
```

If the user provides an exported file:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\xinjian-erp-ad-hourly.ps1") -InputPath "<export.xlsx>" -StoreName "<店铺A>,<店铺B>" -Days 7 -Json
```

If the user is about to export from 心舰 ERP but does not want to provide the filename, wait for a new file in Downloads and analyze it automatically:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\wait-xinjian-export.ps1") -StoreName "<店铺A>,<店铺B>" -Days 7 -TimeoutSec 300 -Json
```

If the user explicitly asks to solve login and the in-app browser is unavailable, use the isolated manual login bridge. It opens Edge/Chrome with a temporary browser profile and local DevTools port. The user must enter credentials and verification manually. Do not read cookies, localStorage, access tokens, or passwords.

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\open-xinjian-login.ps1") -Json
```

After the user confirms login is complete in that browser window, fetch the hourly endpoint through the logged-in page context and run the Excel analyzer:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\fetch-xinjian-browser-data.ps1") -Port 9339 -StoreName "<店铺A>,<店铺B>" -Days 7 -Json
```

This route only asks the page to call the known 心舰 endpoint with `credentials: "include"` and saves the endpoint response for analysis. It must not print or persist session secrets.

If the user explicitly says to run 心舰 through 紫鸟, first try the running 紫鸟 browser CDP bridge. It discovers active `ziniaobrowser.exe` debug ports, opens 心舰 in that 紫鸟 browser, then fetches the same endpoint through the page context:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\xinjian-ziniao-bridge.ps1") -StoreName "<店铺A>,<店铺B>" -Days 7 -Json
```

If the user provides a 心舰 URL, pass it through `-Url`. The bridge must first enumerate already-running debuggable browser tabs, score them against that URL, and try the best matching existing tab. If no 心舰 window is found at all, it opens a controllable Edge/Chrome 心舰 page automatically unless `-NoAutoOpen` is passed:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\xinjian-ziniao-bridge.ps1") -Url "https://erp.xinjianerp.com/index/home" -StoreName "<店铺A>,<店铺B>" -Days 7 -Json
```

If the result is `manual_xinjian_login_in_ziniao_required`, 心舰 is not logged in inside that 紫鸟 browser. The user must complete 心舰 login in the opened 紫鸟 browser window; do not enter credentials or verification for them.

The bridge reports `detected_pages`, `attempts`, `runtime_status`, `auto_open`, `page_url`, and `login_state`. `app_authenticated` means the opened 心舰 page is logged in and the frontend request module was able to call the advertising endpoint. If `auto_open.ok=true` and the result is `manual_login_required`, the controllable browser was opened successfully but 心舰 still needs manual login in that browser. If the result is `xinjian_window_detected_without_debug_port`, Codex saw a likely 心舰 window by DevTools-free window detection and must not open a duplicate window; that window can expose a title and sometimes the address-bar URL through Windows UIA, but it cannot be read or operated like a CDP page because it has no DevTools port. If the result is `target_browser_window_not_detected`, do not ask the user to open it manually first; rerun without `-NoAutoOpen` so the bridge opens a controllable page. If the result is `target_stores_not_found_in_xinjian`, do not ask the user to log in again; the current 心舰 account is authenticated but the requested store names were not found in the available shop list. Use `store_suggestions` to show nearby matches, but do not substitute a different region/store without user confirmation.

The script reads `.xlsx`, `.csv`, and `.json` exports, then groups data by store and hour. Legacy `.xls` files are not treated as supported input unless the local Python environment has a reliable reader added later. It computes ROAS, CTR, CR, CPC, ad spend, ad revenue, orders, clicks, and impressions. The best time period is selected primarily by ROAS, with orders, revenue, clicks, and CPC used as tie breakers.

The PowerShell wrapper writes both a Markdown summary and an Excel workbook by default. In JSON mode, return the path from `excel_output` as the deliverable workbook. The workbook contains:

- `最佳时段`: one best hour row per store.
- `分时明细`: all store-hour aggregates.
- `原始记录`: normalized source rows used in the calculation.
- `说明`: date window, data source, and selection logic.

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

1. Search local exports with the script above.
2. If no usable export exists, ask the user to export the hourly product ad data from 心舰 ERP.
3. If the user can export now, run `wait-xinjian-export.ps1` before they export so the download is analyzed automatically.
4. If Codex in-app browser is available, open 心舰 ERP there and let the user manually log in, then inspect page responses.
5. If the user explicitly asks for a login workaround and accepts a manual browser login, use `open-xinjian-login.ps1` plus `fetch-xinjian-browser-data.ps1`.
6. Do not use system Chrome, BrowserMCP, Ziniao GUI, coordinate clicks, or foreground browser automation unless the user explicitly accepts foreground control for this specific task.

## Report Shape

Return a table with at least:

```text
店铺 | 最佳时段 | ROAS | 广告销售额 | 广告花费 | 广告订单 | 点击 | 展示 | CTR | CR | CPC | 判断
```

Mention the data source, date window, and Excel workbook path. If the script relaxed the date filter because the export had no rows in the requested window, state that clearly.
