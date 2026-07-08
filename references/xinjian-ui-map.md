# Xinjian UI Action Map

Use this reference when the user asks Codex to remember 心舰 ERP pages, buttons, filters, menus, or "像影刀 RPA 一样说什么就干什么".

The machine-readable map lives in:

```text
references/xinjian-ui-map.json
references/xinjian-ui-auto-map.json
references/xinjian-ui-overlay-map.json
references/xinjian-ui-dialog-map.json
references/xinjian-ui-row-action-map.json
references/xinjian-ui-action-catalog.json
references/xinjian-ui-action-catalog.md
```

`xinjian-ui-map.json` is the curated map with manually reviewed actions. `xinjian-ui-auto-map.json` is generated from sanitized CDP DOM captures and is used for broad page/button memory before manual refinement. `xinjian-ui-overlay-map.json` is generated from sanitized dropdown/menu/date/select overlay captures and supplements both maps. `xinjian-ui-dialog-map.json` is generated from sanitized dialog/drawer captures for buttons that only appear after safe openers. `xinjian-ui-row-action-map.json` is generated from sanitized table row-action captures and stores table headers, row action labels, and generic action words from operation columns. `xinjian-ui-action-catalog.json` and `.md` merge those public maps into one compact action catalog for audit, planning, and RPA-style routing.

## Workflow

1. Detect the current 心舰 window:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\detect-ziniao-windows.ps1") -Json
```

Before choosing an action, list what the currently open page already has in memory:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\list-xinjian-page-actions.ps1") -Json
```

`list-xinjian-page-actions.ps1` resolves the current 心舰 URL from visible/debuggable windows read-only, then returns the remembered page, every mapped action on that page, each action's purpose, safety mode, and locator strategy. Pass `-Url "<当前心舰URL>"` to override detection, `-Intent "<用户要做什么>"` to disambiguate multiple open 心舰 windows, or `-SafeOnly` for safe non-write actions only.

To audit global memory quality before deciding what to learn next:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\report-xinjian-action-memory.ps1") -Json
```

`report-xinjian-action-memory.ps1` reads the unified action catalog and reports weak pages, source coverage, locator gaps, audit counts, and per-page recommended learning commands. Use it before broad learning passes so work targets pages with low action count or missing dynamic control memory.

If the current page is missing, weakly mapped, or newly changed, learn it in one safe pass:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\learn-xinjian-current-page.ps1") -Json
```

`learn-xinjian-current-page.ps1` resolves the current page, captures DOM controls, dropdown/select/date overlays, safe dialog/drawer controls, and table row action labels/operation-column action words, then regenerates the public maps and unified action catalog. It does not read cookies, storage, tokens, input values, or table row cell values. Use `-DryRun` to preview the steps, or pass `-SkipDialogs`, `-SkipOverlays`, `-SkipRowActions`, or `-SkipDom` for narrower learning.

To learn every currently debuggable 心舰 page already open in Chrome/Edge, run:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\learn-xinjian-open-pages.ps1") -Json
```

`learn-xinjian-open-pages.ps1` enumerates open DevTools pages on the configured port, de-duplicates by route, runs the current-page learner once per page with map generation deferred, then regenerates the public maps and unified catalog once at the end. Pass explicit `-Url` values or `-MaxPages` for a smaller batch.

2. Query the known map before using screenshots or guessing:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\query-xinjian-ui-action.ps1") -Intent "<用户要做什么>" -Url "<当前心舰URL>" -Json
```

3. To inspect the full remembered button/action catalog:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\generate-xinjian-ui-action-catalog.ps1") -Json
```

The generated `references/xinjian-ui-action-catalog.md` is a human-readable page/action table. The JSON version includes action context, safety mode, source map, locator strategy, raw locator, and an audit section for `manual_review`, `map_only`, and empty-locator actions.

4. For RPA-style routing, convert the mapped intent into a dry-run action plan before clicking:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\invoke-xinjian-ui-action.ps1") -Intent "<用户要做什么>" -Json
```

The invoker reports the matched page/action, safety gate, and locator strategy. If `-Url` is omitted, it detects visible/debuggable 心舰 windows read-only and scores candidate URLs against the user's intent; a single best visible match becomes the current page. Pass `-Url "<当前心舰URL>"` to override detection, or `-NoAutoDetectUrl` to force global matching. It only clicks when `-Execute` is passed. Write/delete/save/submit/export actions stay blocked unless the exact operation is explicitly allowed with `-AllowWrite` or `-AllowExport`.

Locator strategy is layered. Exact selectors, row-action locators, hrefs, visible DOM text, placeholder strings, placeholder lists, and known tab-text lists are used first. For known date/platform lists, the invoker passes the user's original intent into the CDP helper so requests such as `近7天`, `最近七天`, `Shopee`, or `Lazada` can choose the matching visible tab instead of clicking a generic label. When a safe tab/status-tab has no explicit locator, the invoker may click the matching visible action text. When a date filter has no explicit placeholder, it may focus the nearest visible date/select control next to the filter label. Row-level generic entries such as `行分析` and `操作` are recorded as `row_context_required_column_header` when only the table column is known; the invoker refuses to blindly click the first row until a row context or exact row-action button metadata is available.

When `-Url` is provided, query and invoke scripts first scope page-level matches to the current route. Off-page name matches are suppressed unless no current-page match exists, so an intent like `首页` on `/ai/talk` resolves to the current page's 首页 action instead of the 首页 page's unrelated controls.

5. If the target page or route is unclear and a debuggable Chrome/Edge page is available, discover real 心舰 frontend routes and visible menus:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\discover-xinjian-routes.ps1") -Port 9342 -Json
```

Use route discovery to choose a real 心舰 path before opening new pages. It reads Vue Router metadata plus visible link/menu labels only.

6. To expand coverage in batches, crawl unmapped routes and capture their DOM controls:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\report-xinjian-ui-coverage.ps1") -Port 9342 -RefreshRoutes -Json
```

Use the coverage report first. It compares discovered 心舰 routes with the curated map, generated auto map, and local crawl state, then lists pending routes.

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\crawl-xinjian-dom-pages.ps1") -Port 9342 -OnlyUnmapped -MaxPages 20 -Json
```

The crawler opens one route at a time through CDP, captures controls, then closes the temporary tab it opened. It records local attempt state under `.ziniao-ops\xinjian-crawl-state.json`, so empty pages, restricted pages, redirects, and previous failures are not repeatedly retried unless `-RetryAttempted` is passed. It does not click page controls.

7. Promote sanitized local captures into the generated auto map:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\generate-xinjian-ui-auto-map.ps1") -NoMergeExisting -Json
```

The generator skips pages already present in the curated map, removes empty captures, normalizes account-menu labels, skips generic/private-looking values, and marks write/export/batch/edit/save/delete actions as confirmation-required.

8. To capture dynamic overlay controls such as dropdown menus, batch menus, select panels, and date shortcuts:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\capture-xinjian-overlays.ps1") -Port 9342 -Url "<心舰页面URL>" -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\generate-xinjian-ui-overlay-map.ps1") -Json
```

For broad progress across already known pages, crawl mapped routes in batches:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\crawl-xinjian-overlay-pages.ps1") -Port 9342 -OnlyMissing -IncludeSelects -MaxPages 10 -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\generate-xinjian-ui-overlay-map.ps1") -Json
```

The batch crawler opens a temporary CDP tab per mapped route, captures overlay triggers/items, closes the tab, and records local attempt state under `.ziniao-ops\xinjian-overlay-crawl-state.json`.

The overlay probe opens safe Element UI trigger panels (`select`, `cascader`, `dropdown`, date picker), records sanitized generic menu items, and closes the panel. It does not click overlay items. Private-looking select values are filtered at capture time.

9. To capture dialog/drawer controls that only appear after a safe opener:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\capture-xinjian-dialogs.ps1") -Port 9342 -Url "<心舰页面URL>" -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\crawl-xinjian-dialog-pages.ps1") -Port 9342 -OnlyMissing -MaxPages 10 -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\generate-xinjian-ui-dialog-map.ps1") -Json
```

The dialog probe may click safe opener buttons such as `新增`, `编辑`, `详情`, `查看`, `设置`, or `配置`, records sanitized dialog/drawer buttons, field labels, and placeholders, then closes the dialog. It does not click submit/confirm/write buttons, does not type, and does not read input values.

10. To capture table row-level operation buttons without reading row data:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\capture-xinjian-row-actions.ps1") -Port 9342 -Url "<心舰页面URL>" -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\crawl-xinjian-row-action-pages.ps1") -Port 9342 -OnlyMissing -MaxPages 10 -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\generate-xinjian-ui-row-action-map.ps1") -Json
```

The row-action probe reads table headers and row action labels only. For operation columns, it stores recognized generic action words rather than full cell text. It may open non-mutating row menu triggers such as `更多` or `操作`, but it does not click row action menu items and does not read row cell values.

11. If a debuggable Chrome/Edge page is available, capture one current page's real DOM controls:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\capture-xinjian-dom-map.ps1") -Port 9342 -Json
```

12. If the page or button is not debuggable, capture the current page through Windows UIA read-only:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\capture-xinjian-ui-map.ps1") -Json
```

The captures write local observations under `.ziniao-ops\xinjian-dom-captures\`, `.ziniao-ops\xinjian-overlay-captures\`, `.ziniao-ops\xinjian-dialog-captures\`, `.ziniao-ops\xinjian-row-action-captures\`, `.ziniao-ops\xinjian-route-discovery\`, `.ziniao-ops\xinjian-crawl-state.json`, `.ziniao-ops\xinjian-overlay-crawl-state.json`, `.ziniao-ops\xinjian-dialog-crawl-state.json`, `.ziniao-ops\xinjian-row-action-crawl-state.json`, or `.ziniao-ops\xinjian-ui-observations\`. These local files are intentionally ignored by Git. Promote only generic page knowledge into `references/xinjian-ui-map.json`, generated `references/xinjian-ui-auto-map.json`, generated `references/xinjian-ui-overlay-map.json`, generated `references/xinjian-ui-dialog-map.json`, generated `references/xinjian-ui-row-action-map.json`, or the generated catalog.

## Safety

- Capture uses Chrome CDP DOM metadata or Windows UI Automation read-only access. It does not click, type, move the mouse, read cookies, read localStorage/sessionStorage, or read tokens.
- Route discovery uses Chrome CDP to read Vue Router metadata and visible link/menu labels. It does not read cookies, storage, tokens, input values, or table row data.
- Batch crawling only navigates to frontend routes in temporary CDP tabs and closes those tabs after capture. It must not be used to submit forms or run write actions.
- Overlay capture opens panels but does not click overlay items. Treat overlay write/export/batch/edit/delete entries as confirmation-required.
- Dialog capture clicks only safe opener controls and never clicks submit/confirm/write buttons inside the dialog. Treat dialog submit/save/confirm/write entries as confirmation-required.
- Row-action capture reads table headers, row action labels, and operation-column generic action words only; it must not read row cell values or click row action items. It may open non-mutating row menu triggers only to reveal menu labels. Treat row edit/delete/export/write entries as confirmation-required.
- Default capture excludes table row values because they can contain private business data. Use row data only for a user-requested report, not for public skill memory.
- Any action that assigns, claims, saves, submits, deletes, exports, or batch-updates must be treated as confirmation-required unless the user explicitly asks for that exact operation.
- Form-field actions may focus or open the field control only. They must not type values or submit the form unless a separate explicit write/submit action is confirmed.
- `invoke-xinjian-ui-action.ps1` is dry-run by default. `-Execute` may click safe non-write actions through CDP; confirmation-required write/export actions require `-AllowWrite` or `-AllowExport`.
- A mapped locator is a memory aid, not permission to perform a write action.

## Current Coverage

Route discovery has been verified against the logged-in 心舰 frontend and can read about 100+ Vue Router entries from the page. The public action maps currently promote only generic controls from real CDP DOM captures.

Curated mapped pages:

- CRM / 数据概览: `/dataView/data-overview`
- CRM / 达人公海: `/crm/matser/management/highSeas`
- CRM / 我的达人: `/crm/matser/management/myMaster`
- CRM / 重点关注: `/crm/matser/management/focus`
- CRM / 黑名单: `/crm/matser/management/blacklist`
- ADS / 店铺广告分析: `/ad/shop-detail`
- ADS / 广告详情: `/ad/group-detail`
- ADS / 创意详情: `/ad/originality-detail`
- ADS / 广告规则执行日志: `/erp/ads/rule-log`
- System / 下载中心: `/download/list`

Generated auto-map coverage currently includes additional BI, CRM detail, BPM/process, AI, and restricted-state pages captured from logged-in CDP DOM. Query scripts merge the curated and generated maps, with curated pages taking precedence.

Coverage snapshot from the 2026-07-08 CDP crawl:

- Vue Router entries discovered: 109.
- Directly navigable eligible routes after safety exclusions: 56.
- Eligible routes mapped in curated or auto map: 42.
- Eligible routes attempted but not mapped: 14 (`empty`, `noaccess`, or `redirected`).
- Pending eligible routes: 0.
- Public map pages: 10 curated pages plus 38 generated auto-map pages.
- Dynamic overlay coverage: 47 public known pages, 45 attempted by the overlay crawler plus the current open-page learner, 0 pending after exclusions, 26 pages promoted to the overlay map, 291 overlay actions.
- Dialog/drawer coverage: 47 public known pages, 47 attempted by the dialog crawler plus the current open-page learner, 0 pending after exclusions, 9 pages promoted to the dialog map, 41 dialog actions.
- Table row-action coverage: 47 public known pages, 47 attempted by the row-action crawler plus targeted fixed-right operation-column learning, 0 pending after exclusions, 2 pages promoted to the row-action map, 6 row actions.
- Unified action catalog: 49 pages, 625 deduplicated actions, with context, safety mode, source map, locator strategy, and locator metadata. Current catalog audit has 0 `manual_review`, 0 `map_only`, and 0 empty-locator actions; row-level generic actions that cannot be executed without a selected row are marked `row_context_required_column_header`.

Known CRM controls include shop/category/business-owner filters, creator ID search, status tabs, creator assignment/claim/batch buttons, transfer and blacklist restore actions. Write actions are marked confirmation-required.

Known ADS controls include shop/date filters, platform tabs, quick date tabs (`今天`, `昨天`, `近7天`, `近30天`), shop ad metrics columns (`广告花费`, `展现量`, `点击量`, `广告订单量`, `ACoS`, `ROAS`), ad detail keyword/bid columns, creative status/search/batch controls, rule-log export/detail actions, and the download center filters. Export, batch, edit, warning-setting, and restore actions are marked confirmation-required.
