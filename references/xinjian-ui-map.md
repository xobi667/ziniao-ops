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
references/xinjian-ui-action-exercise-report.json
references/xinjian-ui-action-exercise-report.md
references/xinjian-ui-live-button-coverage.json
references/xinjian-ui-live-button-coverage.md
references/xinjian-ui-rpa-readiness.json
references/xinjian-ui-rpa-readiness.md
```

`xinjian-ui-map.json` is the curated map with manually reviewed actions. `xinjian-ui-auto-map.json` is generated from sanitized CDP DOM captures and is used for broad page/button memory before manual refinement; it excludes transient Element UI poppers, date-picker panels, select dropdowns, dialogs, drawers, message boxes, global sidebars, user menus, and theme drawers so dynamic controls are not misfiled as always-visible page buttons. The auto map can also supplement curated pages with live DOM selectors when generic controls are missing from the curated map. `xinjian-ui-overlay-map.json` is generated from sanitized dropdown/menu/date/select overlay captures and supplements both maps. `xinjian-ui-dialog-map.json` is generated from sanitized dialog/drawer captures for buttons that only appear after safe openers. `xinjian-ui-row-action-map.json` is generated from sanitized table row-action captures and stores table headers, row action labels, and generic action words from operation columns. `xinjian-ui-action-catalog.json` and `.md` merge those public maps into one compact action catalog for audit, planning, and RPA-style routing. `xinjian-ui-action-exercise-report.json` and `.md` record sanitized execution evidence for safe route-scoped CDP actions. `xinjian-ui-live-button-coverage.json` and `.md` compare live route-scoped DOM controls against the action catalog to prove whether visible controls are still missing from memory.
`xinjian-ui-rpa-readiness.json` and `.md` summarize catalog quality, live coverage, safe exercise proof, and the remaining non-default execution boundaries.

## Workflow

1. Detect the current 心舰 window:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\detect-ziniao-windows.ps1") -Json
```

Before choosing an action, list what the currently open page already has in memory:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\list-xinjian-page-actions.ps1") -Json
```

`list-xinjian-page-actions.ps1` resolves the current 心舰 URL from visible/debuggable windows read-only, then returns the remembered page, every mapped action on that page, each action's purpose, safety mode, and locator strategy. Read top-level `current_url`, `current_title`, `resolved_port`, `page_kind`, and `next_action` first; login/no-access pages return those fields even when no actions are listed. By default it scans all reachable Chrome/Edge/Ziniao DevTools ports and returns `resolved_port` when a debuggable tab is selected; pass `-Port` only to pin diagnostics to a specific port. Pass `-Url "<当前心舰URL>"` to override detection, `-Intent "<用户要做什么>"` to disambiguate multiple open 心舰 windows, or `-SafeOnly` for safe non-write actions only.

When multiple 心舰 windows are open, URL resolution prefers logged-in business pages over login/restricted pages, even if the login page is the foreground debuggable window. Foreground and intent scoring are used only after business-page candidates are isolated. Passing `-Port` still pins diagnostics to that explicit port.

To audit global memory quality before deciding what to learn next:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\report-xinjian-action-memory.ps1") -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\learn-xinjian-weak-pages.ps1") -DryRun -Json
```

`report-xinjian-action-memory.ps1` reads the unified action catalog and reports weak pages, source coverage, locator gaps, audit counts, and per-page recommended learning commands. Dynamic source coverage is page-level, not only action-level: overlay/dialog/row-action maps keep sanitized page evidence even when a safe probe found no public overlay, dialog, or row-action buttons. That prevents the audit from repeatedly retrying pages that were already checked and genuinely had no promotable dynamic controls. Low-action app-shell pages are not weak when their only remembered controls are the generic shell actions and overlay/dialog/row-action probes have already covered the page. Restricted/no-access pages are tracked as restricted rather than learnable weak pages. `learn-xinjian-weak-pages.ps1` uses that report to select the highest-risk learnable pages and run the safe current-page learner in a bounded batch. It records local attempt state under `.ziniao-ops\xinjian-weak-page-learn-state.json` and skips recently attempted pages by default so learning keeps moving forward; pass `-RetryAttempted` to revisit them. Use `-DryRun` first, then rerun without `-DryRun` for the selected batch. When the audit has no weak pages, dry-run returns `ok=true` with `next_action = no_weak_pages_found`.

If the current page is missing, weakly mapped, or newly changed, learn it in one safe pass:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\learn-xinjian-current-page.ps1") -Json
```

`learn-xinjian-current-page.ps1` resolves the current page, auto-selects a reachable debuggable 心舰 port, captures DOM controls, dropdown/select/date overlays, safe dialog/drawer controls, and table row action labels/operation-column action words, then regenerates the public maps and unified action catalog. Its output includes top-level `current_url`, `current_title`, `resolved_port`, and `page_kind`. If the resolved page is a login, restricted, 401, 404, or no-access page, dry-run and real learning both stop with `manual_login_required_in_debuggable_xinjian_browser` or `open_valid_xinjian_business_page` instead of learning the wrong page. It validates that every capture's `matched_page.url` route matches the target route; if a capture lands on a different page, generation is skipped so wrong-page controls are not promoted. It does not read cookies, storage, tokens, input values, or table row cell values. Use `-DryRun` to preview the steps, or pass `-SkipDialogs`, `-SkipOverlays`, `-SkipRowActions`, or `-SkipDom` for narrower learning.

To learn every currently debuggable 心舰 page already open in Chrome/Edge, run:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\learn-xinjian-open-pages.ps1") -Json
```

`learn-xinjian-open-pages.ps1` enumerates already open reachable DevTools 心舰 pages, de-duplicates by route, runs the current-page learner once per page with map generation deferred, then regenerates the public maps and unified catalog once at the end. It does not open new browser windows or tabs. Pass `-Port` only to pin scanning to an existing debug port, or pass explicit `-Url` values / `-MaxPages` for a smaller batch.

2. Query the known map before using screenshots or guessing:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\query-xinjian-ui-action.ps1") -Intent "<用户要做什么>" -Url "<当前心舰URL>" -Json
```

By default the query script reads `references/xinjian-ui-action-catalog.json` first, so generated read-only table-header memory is available to intent matching. If the catalog is unavailable, it falls back to the raw curated/auto/overlay/dialog/row-action maps.

When an intent names a page, especially with `打开`, `进入`, or another navigation verb, the query layer synthesizes a safe `page_navigation` action from the catalog page route. This keeps page-level requests such as `打开下载中心` from being misrouted to row-level actions like a report download operation.

After changing query ranking or RPA routing behavior, run:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\test-xinjian-rpa-routing.ps1") -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\test-xinjian-row-context-inference.ps1") -Json
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

The invoker reports the matched page/action, safety gate, locator strategy, `execution_backend`, and top-level `current_url`, `current_title`, `resolved_port`, and `page_kind`. If `-Url` is omitted, it detects visible/debuggable 心舰 windows read-only and scores candidate URLs against the user's intent; a single best visible match becomes the current page. By default it scans reachable DevTools ports instead of assuming `9342`; pass `-Port` only to pin execution to a specific browser. Pass `-Url "<当前心舰URL>"` to override detection, or `-NoAutoDetectUrl` to force global matching. It only clicks when `-Execute` is passed. Write/delete/save/submit/export actions stay blocked unless the exact operation is explicitly allowed with `-AllowWrite` or `-AllowExport`.

When no debuggable CDP port is resolved, the invoker can still execute mapped safe non-write controls through Windows UI Automation if the already-open 心舰 window exposes a matching UIA element. In that case dry-run reports `execution_backend = "uia"`, `uia_fallback_available = true`, and `can_execute = true`; `-Execute` invokes the UIA `InvokePattern` or `SelectionItemPattern` without moving the mouse or opening a duplicate browser. UIA fallback is deliberately narrow: write/export actions, row-context actions, read-only table-column memory, and unknown-safety actions remain blocked.

Locator strategy is layered. Exact selectors, row-action locators, hrefs, visible DOM text, placeholder strings, placeholder lists, and known tab-text lists are used first. For known date/platform lists, the invoker passes the user's original intent into the CDP helper so requests such as `近7天`, `最近七天`, `Shopee`, or `Lazada` can choose the matching visible tab instead of clicking a generic label. When a safe tab/status-tab has no explicit locator, the invoker may click the matching visible action text. When a date filter has no explicit placeholder, it may focus the nearest visible date/select control next to the filter label. Observed table metric/header entries such as `ROAS`, `广告花费`, and `转化率` are recorded as read-only `table_column` actions with `read_table_column_header`; they are query/planning memory and are not clicked. Row-level entries such as `行分析`, `操作`, `详情`, `编辑`, `删除`, `分配`, or `认领` require resolved row context. Pass `-RowIndex <1-based row number>` / `-RowText "<visible row text>"`, or include a clear row phrase in the intent such as `第1行编辑`, `第一行详情`, or `包含 xxx 的行编辑`; the invoker refuses to blindly click the first row. Explicit row arguments override inferred row context. Write/export row actions still require `-AllowWrite` or `-AllowExport`.

Intent ranking is action-aware. When the user says `打开`, `展开`, `选择`, `筛选`, or `切换`, prefer executable overlay triggers/items over passive `filter_input` and read-only `table_column` memories with the same label. When the user says `查看` or asks for a metric/column, keep table-column matches read-only and do not click them.

When `-Url` is provided, query and invoke scripts first scope page-level matches to the current route. Off-page name matches are suppressed unless no current-page match exists, except explicit page-navigation intents where the named page route is returned as `page_navigation`. This means an intent like `首页` on `/ai/talk` can still resolve to the current page's 首页 action, while `打开下载中心` resolves to the 下载中心 route instead of a row operation.

To batch exercise all route-scoped safe CDP-clickable actions that are already in the catalog, use:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\exercise-xinjian-safe-actions.ps1") -Port 9339 -MaxActions 50 -WritePublicReport -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\exercise-xinjian-safe-actions.ps1") -Port 9339 -RetryFailed -WritePublicReport -Json
```

The exercise script opens temporary CDP tabs, executes only `safe_execute_allowed` route-scoped actions, and records local state under `.ziniao-ops\xinjian-safe-action-exercise-state.json`. It excludes read-only table columns, write/export/submit/delete actions, row actions without row context, account menus by default, and no-route UIA globals. `-WritePublicReport` updates the sanitized public exercise report without storing cookies, tokens, input values, row data, or private business values.

To prove that live route pages have no unremembered visible controls, run the live coverage audit:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\audit-xinjian-live-button-coverage.ps1") -Port 9339 -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\audit-xinjian-live-button-coverage.ps1") -UseExistingCaptures -Json
```

The live audit opens or reuses route-scoped CDP captures, filters non-business chrome such as global sidebars, user menus, theme drawers, pagination, vendor watermarks, and table operation headers, then compares sanitized control names/selectors against the unified action catalog. It writes `references/xinjian-ui-live-button-coverage.json` and `.md`; local raw captures stay under `.ziniao-ops`.

To answer "还缺什么" from public evidence without opening a browser, generate the RPA readiness report:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\report-xinjian-rpa-readiness.ps1") -Json
```

The readiness report writes `references/xinjian-ui-rpa-readiness.json` and `.md`. It checks whether every catalog action has purpose, function source, context, locator metadata, and whether live controls and safe execution evidence still have gaps. Remaining boundaries such as no-access pages, confirmation-required write/export actions, row-context actions, and read-only table-column memory are listed separately so they are not confused with missing button memory. Row-context actions are executable only with explicit `-RowIndex` / `-RowText` or clear row intent inferred from the user's wording.

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
Read `pending_count`, `overlay_pending_count`, `dialog_pending_count`, `row_action_pending_count`, `pending_coverage_complete`, and `next_action` first. `route_mapping_complete` can be false when remaining routes were already attempted and proved empty, no-access, or redirected; those should not be relearned unless permissions or routing change.

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\crawl-xinjian-dom-pages.ps1") -Port 9342 -OnlyUnmapped -MaxPages 20 -Json
```

The crawler opens one route at a time through CDP, captures controls, then closes the temporary tab it opened. It records local attempt state under `.ziniao-ops\xinjian-crawl-state.json`, so empty pages, restricted pages, redirects, and previous failures are not repeatedly retried unless `-RetryAttempted` is passed. It does not click page controls.

7. Promote sanitized local captures into the generated auto map:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\generate-xinjian-ui-auto-map.ps1") -NoMergeExisting -Json
```

The generator can supplement curated pages with sanitized generated controls, removes empty captures, normalizes account-menu labels, skips generic/private-looking values, excludes transient overlay/dialog/global shell controls, records live DOM CSS selectors for executable controls, and marks write/export/batch/edit/save/delete actions as confirmation-required.

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

The batch crawler opens a temporary CDP tab per mapped route, captures overlay triggers/items, closes the tab, and records local attempt state under `.ziniao-ops\xinjian-overlay-crawl-state.json`. Generated overlay pages are retained with `evidence.coverage_result = probe_ran_no_public_overlay_actions` when the probe ran safely but found no public overlay actions.

The overlay probe opens safe Element UI trigger panels (`select`, `cascader`, `dropdown`, date picker), records sanitized generic menu items, and closes the panel. It does not click overlay items. Private-looking select values are filtered at capture time. The public generator also filters stale action-menu leakage, so write-like menu items such as batch delete, information update, or creator transfer are not promoted when they were observed under filter-only triggers such as shop/category/business/age selectors.

9. To capture dialog/drawer controls that only appear after a safe opener:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\capture-xinjian-dialogs.ps1") -Port 9342 -Url "<心舰页面URL>" -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\crawl-xinjian-dialog-pages.ps1") -Port 9342 -OnlyMissing -MaxPages 10 -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\generate-xinjian-ui-dialog-map.ps1") -Json
```

The dialog probe may click safe opener buttons such as `新增`, `编辑`, `详情`, `查看`, `设置`, or `配置`, records sanitized dialog/drawer buttons, field labels, and placeholders, then closes the dialog. It does not click submit/confirm/write buttons, does not type, and does not read input values. Generated dialog pages are retained with `evidence.coverage_result = probe_ran_no_public_dialog_actions` when no public dialog controls are promotable.

10. To capture table row-level operation buttons without reading row data:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\capture-xinjian-row-actions.ps1") -Port 9342 -Url "<心舰页面URL>" -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\crawl-xinjian-row-action-pages.ps1") -Port 9342 -OnlyMissing -MaxPages 10 -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\generate-xinjian-ui-row-action-map.ps1") -Json
```

The row-action probe reads table headers and row action labels only. For operation columns, it stores recognized generic action words rather than full cell text. It may open non-mutating row menu triggers such as `更多` or `操作`, but it does not click row action menu items and does not read row cell values. Generated row-action pages are retained with `evidence.coverage_result = probe_ran_no_public_row_actions` when no row actions are visible or promotable.

11. If a debuggable Chrome/Edge page is available, capture one current page's real DOM controls:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\capture-xinjian-dom-map.ps1") -Port 9342 -Json
```

12. If the page or button is not debuggable, capture the current page through Windows UIA read-only:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\capture-xinjian-ui-map.ps1") -Json
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\capture-xinjian-ui-map.ps1") -CompareCatalog -Json
```

The UIA capture filters private/noisy browser controls, pagination-only list items, close glyphs, and non-action buttons before saving observations. `-CompareCatalog` compares the visible controls against the current unified action catalog and reports matched controls plus non-navigation controls that are still missing from memory.

The captures write local observations under `.ziniao-ops\xinjian-dom-captures\`, `.ziniao-ops\xinjian-overlay-captures\`, `.ziniao-ops\xinjian-dialog-captures\`, `.ziniao-ops\xinjian-row-action-captures\`, `.ziniao-ops\xinjian-route-discovery\`, `.ziniao-ops\xinjian-crawl-state.json`, `.ziniao-ops\xinjian-overlay-crawl-state.json`, `.ziniao-ops\xinjian-dialog-crawl-state.json`, `.ziniao-ops\xinjian-row-action-crawl-state.json`, or `.ziniao-ops\xinjian-ui-observations\`. These local files are intentionally ignored by Git. Promote only generic page knowledge into `references/xinjian-ui-map.json`, generated `references/xinjian-ui-auto-map.json`, generated `references/xinjian-ui-overlay-map.json`, generated `references/xinjian-ui-dialog-map.json`, generated `references/xinjian-ui-row-action-map.json`, or the generated catalog.

## Safety

- Capture uses Chrome CDP DOM metadata or Windows UI Automation read-only access. It does not click, type, move the mouse, read cookies, read localStorage/sessionStorage, or read tokens.
- The current-page learner validates capture route consistency before generating public maps. A mismatched `matched_page.url` is treated as a failed learning pass, not as usable memory.
- Route discovery uses Chrome CDP to read Vue Router metadata and visible link/menu labels. It does not read cookies, storage, tokens, input values, or table row data.
- Batch crawling only navigates to frontend routes in temporary CDP tabs and closes those tabs after capture. It must not be used to submit forms or run write actions.
- Overlay capture opens panels but does not click overlay items. Treat overlay write/export/batch/edit/delete entries as confirmation-required.
- Dialog capture clicks only safe opener controls and never clicks submit/confirm/write buttons inside the dialog. Treat dialog submit/save/confirm/write entries as confirmation-required.
- Row-action capture reads table headers, row action labels, and operation-column generic action words only; it must not read row cell values or click row action items. It may open non-mutating row menu triggers only to reveal menu labels. Treat row edit/delete/export/write entries as confirmation-required.
- Default capture excludes table row values because they can contain private business data. Use row data only for a user-requested report, not for public skill memory.
- Any action that assigns, claims, saves, submits, deletes, exports, or batch-updates must be treated as confirmation-required unless the user explicitly asks for that exact operation.
- Form-field actions may focus or open the field control only. They must not type values or submit the form unless a separate explicit write/submit action is confirmed.
- `invoke-xinjian-ui-action.ps1` is dry-run by default. `-Execute` may click safe non-write actions through CDP, or through Windows UI Automation when the current non-debuggable 心舰 window has a matching mapped UIA control. Confirmation-required write/export actions require `-AllowWrite` or `-AllowExport`, and UIA fallback never broadens those permissions.
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

Coverage snapshot validated from the logged-in CDP page on 2026-07-09:

- Vue Router entries discovered: 109.
- Directly navigable eligible routes after safety exclusions: 56.
- Eligible routes mapped in curated or auto map: 42.
- Eligible routes attempted but not mapped: 14 (`empty`, `noaccess`, or `redirected`).
- Pending eligible routes: 0.
- Public map pages: 10 curated route pages plus one curated global action group and 48 generated auto-map pages.
- Dynamic overlay coverage: 47 public known pages, 0 pending after exclusions, 163 overlay actions after pagination-trigger filtering, stale action-menu leakage filtering, latest-capture replacement, and same-context de-duplication.
- Dialog/drawer coverage: 47 public known pages, 0 pending after exclusions, 9 pages with promoted dialog actions, 38 pages retained as safely probed with no public dialog actions, 41 dialog actions.
- Table row-action coverage: 47 public known pages, 0 pending after exclusions, 2 pages with promoted row actions, 45 pages retained as safely probed with no public row actions, 6 row actions.
- Unified action catalog: 49 pages, 1117 deduplicated actions, with context, safety mode, source map, locator strategy, and locator metadata. This includes 460 read-only `table_column` actions for remembered table metrics/headers, including 82 generated from sanitized public table-header metadata, and 364 generated actions with live CSS selectors. Current catalog audit has 0 `manual_review`, 0 `map_only`, and 0 empty-locator actions. The global memory report uses live coverage evidence and now shows dynamic page coverage of 47 overlay pages, 47 dialog pages, and 47 row-action pages, with 0 weak pages. Sparse shell pages are tagged as fully covered when live DOM coverage proves all visible controls are matched, and restricted/no-access pages are tracked as restricted rather than learnable weak pages. Row-level generic actions that cannot be executed without a selected row are marked `row_context_required_column_header`, and row-level dialog openers are marked `row_context_required_dialog`.
- Live button coverage audit: 48 catalog routes selected, 47 live pages captured, 1 no-access page, 827 visible business controls observed, 827 matched, 0 missing controls.
- Safe action exercise: 551 route-scoped CDP-clickable `safe_execute_allowed` actions verified by actual execution with 0 failures. The exercise scope excludes read-only table-column memory, confirmation-required write/export actions, account menus, row actions without row context, and no-route UIA global module switches.
- RPA readiness: catalog quality has 0 missing purpose, 0 missing function source, 0 missing context, 0 manual-review/map-only/empty-locator actions. Remaining non-default boundaries are 1 no-access live page, 83 confirmation-required write actions, 9 confirmation-required export actions, 12 row-context actions that require explicit or inferred row context, and 460 read-only table-column memories.

Known CRM controls include shop/category/business-owner filters, creator ID search, status tabs, creator assignment/claim/batch buttons, transfer and blacklist restore actions. Write actions are marked confirmation-required.

Known ADS/data controls include shop/date filters, platform tabs, quick date tabs (`今天`, `昨天`, `近7天`, `近30天`), shop/product ad metrics columns (`广告花费`, `展现量`, `点击量`, `广告订单量`, `ACoS`, `ROAS`, `CIR`, `转化率`), ad detail keyword/bid columns, creative status/search/batch controls, rule-log export/detail actions, and the download center filters. Table metric columns are read-only memory; export, batch, edit, warning-setting, and restore actions are marked confirmation-required.
