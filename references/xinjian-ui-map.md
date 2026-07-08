# Xinjian UI Action Map

Use this reference when the user asks Codex to remember 心舰 ERP pages, buttons, filters, menus, or "像影刀 RPA 一样说什么就干什么".

The machine-readable map lives in:

```text
references/xinjian-ui-map.json
```

## Workflow

1. Detect the current 心舰 window:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\detect-ziniao-windows.ps1") -Json
```

2. Query the known map before using screenshots or guessing:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\query-xinjian-ui-action.ps1") -Intent "<用户要做什么>" -Url "<当前心舰URL>" -Json
```

3. If a debuggable Chrome/Edge page is available, capture real DOM controls:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\capture-xinjian-dom-map.ps1") -Port 9342 -Json
```

4. If the page or button is not debuggable, capture the current page through Windows UIA read-only:

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $ZiniaoOpsHome "scripts\capture-xinjian-ui-map.ps1") -Json
```

The captures write local observations under `.ziniao-ops\xinjian-dom-captures\` or `.ziniao-ops\xinjian-ui-observations\`. These local files are intentionally ignored by Git. Promote only generic page knowledge into `references/xinjian-ui-map.json`.

## Safety

- Capture uses Chrome CDP DOM metadata or Windows UI Automation read-only access. It does not click, type, move the mouse, read cookies, read localStorage/sessionStorage, or read tokens.
- Default capture excludes table row values because they can contain private business data. Use row data only for a user-requested report, not for public skill memory.
- Any action that assigns, claims, saves, submits, deletes, exports, or batch-updates must be treated as confirmation-required unless the user explicitly asks for that exact operation.
- A mapped locator is a memory aid, not permission to perform a write action.

## Current Coverage

Mapped page:

- CRM / 达人公海: `/crm/matser/management/highSeas`

Known controls on 达人公海:

- Top modules: `BI`, `ERP`, `ADS`, `CRM`, `设置`.
- Filters: `选择店铺`, `品类`, `全部商务`, `地区`, `粉丝数`, `性别分布`, `年龄分布`, `选择标签`, `达人ID`.
- Read-only buttons/tabs: `搜索`, `重置`, `全部`, `已触达`, `已申样`, `合作中`, `已出单`.
- Confirmation-required actions: `分配达人`, `认领达人`, `批量操作`.
- Table columns: `画像 / 品类`, `粉丝数`, `GMV`, `Item Sold`, `达人标签`, `跟进商务`, `状态`, `交互时间`.
