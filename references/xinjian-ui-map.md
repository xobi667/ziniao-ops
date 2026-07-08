# Xinjian UI Action Map

Use this reference when the user asks Codex to remember 心舰 ERP pages, buttons, filters, menus, or "像影刀 RPA 一样说什么就干什么".

The machine-readable map lives in:

```text
references/xinjian-ui-map.json
references/xinjian-ui-auto-map.json
```

`xinjian-ui-map.json` is the curated map with manually reviewed actions. `xinjian-ui-auto-map.json` is generated from sanitized CDP DOM captures and is used for broad page/button memory before manual refinement.

## Workflow

1. Detect the current 心舰 window:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\detect-ziniao-windows.ps1") -Json
```

2. Query the known map before using screenshots or guessing:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\query-xinjian-ui-action.ps1") -Intent "<用户要做什么>" -Url "<当前心舰URL>" -Json
```

3. If the target page or route is unclear and a debuggable Chrome/Edge page is available, discover real 心舰 frontend routes and visible menus:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\discover-xinjian-routes.ps1") -Port 9342 -Json
```

Use route discovery to choose a real 心舰 path before opening new pages. It reads Vue Router metadata plus visible link/menu labels only.

4. To expand coverage in batches, crawl unmapped routes and capture their DOM controls:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\report-xinjian-ui-coverage.ps1") -Port 9342 -RefreshRoutes -Json
```

Use the coverage report first. It compares discovered 心舰 routes with the curated map, generated auto map, and local crawl state, then lists pending routes.

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\crawl-xinjian-dom-pages.ps1") -Port 9342 -OnlyUnmapped -MaxPages 20 -Json
```

The crawler opens one route at a time through CDP, captures controls, then closes the temporary tab it opened. It records local attempt state under `.ziniao-ops\xinjian-crawl-state.json`, so empty pages, restricted pages, redirects, and previous failures are not repeatedly retried unless `-RetryAttempted` is passed. It does not click page controls.

5. Promote sanitized local captures into the generated auto map:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\generate-xinjian-ui-auto-map.ps1") -NoMergeExisting -Json
```

The generator skips pages already present in the curated map, removes empty captures, normalizes account-menu labels, skips generic/private-looking values, and marks write/export/batch/edit/save/delete actions as confirmation-required.

6. If a debuggable Chrome/Edge page is available, capture one current page's real DOM controls:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\capture-xinjian-dom-map.ps1") -Port 9342 -Json
```

7. If the page or button is not debuggable, capture the current page through Windows UIA read-only:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\capture-xinjian-ui-map.ps1") -Json
```

The captures write local observations under `.ziniao-ops\xinjian-dom-captures\`, `.ziniao-ops\xinjian-route-discovery\`, `.ziniao-ops\xinjian-crawl-state.json`, or `.ziniao-ops\xinjian-ui-observations\`. These local files are intentionally ignored by Git. Promote only generic page knowledge into `references/xinjian-ui-map.json` or generated `references/xinjian-ui-auto-map.json`.

## Safety

- Capture uses Chrome CDP DOM metadata or Windows UI Automation read-only access. It does not click, type, move the mouse, read cookies, read localStorage/sessionStorage, or read tokens.
- Route discovery uses Chrome CDP to read Vue Router metadata and visible link/menu labels. It does not read cookies, storage, tokens, input values, or table row data.
- Batch crawling only navigates to frontend routes in temporary CDP tabs and closes those tabs after capture. It must not be used to submit forms or run write actions.
- Default capture excludes table row values because they can contain private business data. Use row data only for a user-requested report, not for public skill memory.
- Any action that assigns, claims, saves, submits, deletes, exports, or batch-updates must be treated as confirmation-required unless the user explicitly asks for that exact operation.
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

Known CRM controls include shop/category/business-owner filters, creator ID search, status tabs, creator assignment/claim/batch buttons, transfer and blacklist restore actions. Write actions are marked confirmation-required.

Known ADS controls include shop/date filters, platform tabs, quick date tabs (`今天`, `昨天`, `近7天`, `近30天`), shop ad metrics columns (`广告花费`, `展现量`, `点击量`, `广告订单量`, `ACoS`, `ROAS`), ad detail keyword/bid columns, creative status/search/batch controls, rule-log export/detail actions, and the download center filters. Export, batch, edit, warning-setting, and restore actions are marked confirmation-required.
