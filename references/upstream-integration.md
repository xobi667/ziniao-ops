# Upstream Integration

`ziniao-ops` includes upstream capabilities in three ways:

1. Built in: implemented directly in this repo.
2. Optional external adapter: this repo can call an installed upstream tool, but does not require it.
3. Sync-only mirror: this repo can clone/fetch the upstream into ignored `.upstreams/` for review, but does not copy code into the public package.

This is deliberate. Some upstreams are full products or have licenses that do not allow code copying into a public commercial-ready repo. Syncing them locally keeps updates reviewable without mixing license obligations into `ziniao-ops`.

## Capability Matrix

| Capability | Source inspiration | Status in `ziniao-ops` |
| --- | --- | --- |
| Employee-local Ziniao store discovery | Existing package + Vibe Seller store isolation | Built in through `sync-ziniao-shops.py`, `open-store.ps1`, `open-shop.ps1` |
| Fuzzy store matching | Existing package | Built in |
| One sentence open flow | Existing package | Built in through `open-store.ps1` |
| Windows Ziniao launch and login handoff | Existing package | Built in through `setup-ziniao.ps1` and `open-store.ps1` |
| Shopee/TikTok WebDriver opening | Existing package | Built in |
| Lazada GUI opening | Existing package | Built in |
| Operations module routing | User requirement + seller platforms | Built in through view intents |
| Safe popup handling | Existing package | Built in as reference rules |
| Standard operations report | Vibe Seller task report idea | Built in through `scripts/new-ops-report.ps1` |
| Upstream status check | User requirement | Built in through `scripts/check-upstreams.ps1` |
| Local upstream mirror sync | User requirement | Built in through `scripts/sync-upstreams.ps1` |
| Optional `ziniao` CLI/MCP route | `tianyehedashu/ziniao-mcp` / PyPI `ziniao` | Optional wrapper through `scripts/invoke-ziniao-cli.ps1` |
| Optional `auto-ziniao` flow route | `WW-AI-Lab/auto-ziniao` | Optional wrapper through `scripts/invoke-auto-ziniao.ps1`; external install required |
| BrowserMCP existing-profile concept | `BrowserMCP/mcp` | Optional external MCP server; Chrome extension and MCP client config still required |
| Existing browser/CDP endpoint connection | `ChromeDevTools/chrome-devtools-mcp`, `microsoft/playwright-mcp`, `Rainmen-xia/chrome-debug-mcp` | Built into 心舰 bridge through CDP page discovery; external MCP routes remain optional |
| Structured low-token page snapshots | `microsoft/playwright-mcp`, `echo-lumen/cdp-browser-mcp`, `Silbercue/public-browser` | Reference only for future page-reading improvements; current 心舰 workflow fetches data endpoints directly |
| Multi-tab target matching | Chrome DevTools MCP/Public Browser/CDP MCP patterns | Built into `scripts\xinjian-ziniao-bridge.ps1`: score all debuggable tabs by requested URL before opening a new tab |
| Vibe Seller full web service / agents | `zpoint/vibe-seller` | Optional local install under `.ziniao-ops\tools`; not started by default, because this package must remain a simple Codex skill |
| auto-ziniao WebAdmin / self-heal internals | `WW-AI-Lab/auto-ziniao` | Sync-only/reference; license is personal/internal-use |

## Commands

Install or refresh optional upstream commands on the current computer:

```powershell
.\scripts\install-upstream-tools.ps1
```

Install the generic browser MCP routes too:

```powershell
.\scripts\install-upstream-tools.ps1 -InstallGenericBrowserMcps
```

Check upstream remote commits:

```powershell
.\scripts\check-upstreams.ps1
```

Clone or update Git-based upstream mirrors into ignored `.upstreams/`:

```powershell
.\scripts\sync-upstreams.ps1
```

Check which optional adapters are available on this machine:

```powershell
.\scripts\status-upstream-adapters.ps1
```

Current optional installer targets:

- `ziniao` from PyPI.
- `@ww-ai-lab/auto-ziniao` from npm.
- `@browsermcp/mcp` from npm.
- `vibe-seller` from PyPI, installed into local `.ziniao-ops\tools\vibe-seller-venv`.
- Playwright Chromium for Vibe Seller, installed into local `.ziniao-ops\tools\playwright-browsers`.
- Browser-control MCPs such as `chrome-devtools-mcp`, `@playwright/mcp`, `cdp-browser-mcp`, and `public-browser` are tracked as GitHub references. Install them only when the user explicitly asks for a generic MCP route; the 心舰 data workflow should first use the purpose-built CDP bridge.

Call optional `ziniao` CLI route after the user explicitly asks for it:

```powershell
.\scripts\invoke-ziniao-cli.ps1 -CommandArgs "--help"
.\scripts\invoke-ziniao-cli.ps1 -AllowExternalCommand -CommandArgs "site","--help"
```

Call optional `auto-ziniao` route:

```powershell
.\scripts\invoke-auto-ziniao.ps1 -Action list
.\scripts\invoke-auto-ziniao.ps1 -Action validate -FlowId orders_overview
.\scripts\invoke-auto-ziniao.ps1 -Action run -FlowId orders_overview -Param store_name=EXAMPLE -NoHeal -AllowExternalRunner
```

Use BrowserMCP only after the MCP server command and Chrome extension are configured outside this repo.
Use Chrome DevTools MCP or Playwright MCP only as optional external routes. Prefer `--browser-url` / `--cdp-endpoint` against an already-running local browser profile when the user wants manual login state reused, and keep the same no-secret boundary.
Use Vibe Seller only after the user explicitly asks for the full service route and provides its required local configuration; do not start its long-running server as part of normal `ziniao-ops` open-store work.

Create a standard report:

```powershell
.\scripts\new-ops-report.ps1 -Store EXAMPLE -Platform shopee -View overview -MetricsJson '{"orders":12}'
```

## Sync Rules

- `.upstreams/` is ignored by Git and must stay out of releases.
- `sync_mode=mirror` means local clone/fetch is allowed for review.
- `sync_mode=mirror-reference-only` means local clone/fetch is allowed, but code must not be copied into the public repo without explicit permission.
- `sync_mode=manual` means review the URL manually; there is no reliable Git sync target.
- After adopting an upstream idea, update this file and run `scripts/validate-public.ps1`.
