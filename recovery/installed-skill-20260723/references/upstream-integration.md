# Upstream Integration

`ziniao-ops` includes upstream capabilities in three ways:

1. Built in: implemented directly in this repo.
2. Optional external adapter: this repo can call an installed upstream tool, but does not require it.
3. Sync-only mirror: this repo can clone/fetch the upstream into ignored `.upstreams/` for review, but does not copy code into the public package.

This is deliberate. Some upstreams are full products or have licenses that do not allow code copying into a public commercial-ready repo. Syncing them locally keeps updates reviewable without mixing license obligations into `ziniao-ops`.

Browser control is not an upstream adapter. In both Codex CLI and Codex IDE, normal web-page interaction uses the Codex built-in Browser described in [codex-browser.md](codex-browser.md). This package does not install, synchronize, recommend, or invoke generic browser MCP servers.

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
| Codex web-page interaction | Codex built-in Browser | Default in CLI and IDE when `browser:control-in-app-browser` is available |
| Optional `ziniao` CLI route | PyPI `ziniao` | Optional wrapper through `scripts/invoke-ziniao-cli.ps1`; store scan/match/start only |
| Optional `auto-ziniao` flow route | `WW-AI-Lab/auto-ziniao` | Optional wrapper through `scripts/invoke-auto-ziniao.ps1`; external install required |
| Existing local CDP endpoint connection | Purpose-built 心舰 compatibility scripts | Explicit legacy fallback only; never auto-selected over the Codex built-in Browser |
| Structured page snapshots | Codex built-in Browser | Use Browser-provided DOM/accessibility and screenshot capabilities for normal page reading |
| Multi-tab target matching | Purpose-built local compatibility logic | Legacy bridge scores already-open debuggable tabs only after explicit user selection |
| Vibe Seller full web service / agents | `zpoint/vibe-seller` | Optional local install under `.ziniao-ops\tools`; not started by default, because this package must remain a simple Codex skill |
| auto-ziniao WebAdmin / self-heal internals | `WW-AI-Lab/auto-ziniao` | Sync-only/reference; license is personal/internal-use |

## Commands

Install or refresh optional upstream commands on the current computer:

```powershell
.\scripts\install-upstream-tools.ps1
```

Do not use this installer to add browser-control servers. The Codex built-in Browser is a Codex runtime capability, not an npm package or upstream command installed by this repository. If Browser is unavailable in the current session, report that blocker instead of installing an MCP replacement.

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
- `vibe-seller` from PyPI, installed into local `.ziniao-ops\tools\vibe-seller-venv`.
- Playwright Chromium for Vibe Seller, installed into local `.ziniao-ops\tools\playwright-browsers`.
- Generic browser MCP packages are not installer targets or tracked sync sources. Playwright Chromium above belongs only to the explicitly requested Vibe Seller service and is not the default Browser route.

Call the optional `ziniao` CLI route only for local store scanning, matching, or startup:

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

Use the Codex built-in Browser for web navigation, visible-data reading, clicking, typing, and screenshots in both CLI and IDE. Do not configure a separate browser MCP or extension route.
Use direct local CDP/UIA or a temporary Edge bridge only as an explicitly selected legacy fallback for a particular Ziniao/Xinjian local browser context. Never copy browser sessions or treat the legacy bridge as the default.
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
- Generic browser MCP repositories are not tracked or synchronized. Browser behavior comes from the Codex built-in Browser, not `.upstreams/`.
- After adopting an upstream idea, update this file and run `scripts/validate-public.ps1`.
