# External project references

This package is a lightweight Codex skill for employee-local Ziniao store opening and operations-page navigation. It is not an official Ziniao product and does not vendor code from the projects below.

Tracked upstream names, URLs and branch notes live in [upstreams.md](upstreams.md) and [upstreams.json](upstreams.json). Use `scripts/check-upstreams.ps1` from the repo root before reviewing upstream changes.
Exact feature status, optional adapters, and sync commands live in [upstream-integration.md](upstream-integration.md).

## Vibe Seller

Reference: https://github.com/zpoint/vibe-seller

Useful ideas to keep:

- Local-first seller automation: store data, logs, screenshots and memories should stay on the employee's machine unless the user explicitly sends a report elsewhere.
- Store isolation: each task must target one matched local Ziniao store/browser profile; do not cross-use another store's browser or data.
- Browser-control preference: after opening the store environment, use browser/DOM/CDP style control when available; fall back to visual UI only when a stable browser interface is not available.
- Task-report shape: when a user asks to "check data", return a report with store, platform, time range, page/module, visible metrics, actions taken, and blockers.
- Long-term enhancement: add optional per-store notes under a local ignored folder such as `.ziniao-ops/stores/<store>/notes.md` only after the user asks for persistent memory.

Do not copy Vibe Seller's product assumptions into this skill:

- Do not require users to run a web service or open a web console.
- Do not require LLM API keys.
- Do not ask employees to store Ziniao account passwords in this package.
- Do not implement autonomous spending/editing actions by default.

## auto-ziniao / Ziniao Assistant / OpenClaw route

Reference: https://github.com/WW-AI-Lab/auto-ziniao

Useful ideas to keep:

- Acknowledge a second integration route exists: Ziniao Assistant/OpenClaw-style key-based automation through `ZCLAW_API_KEY`.
- Keep secrets out of the repo. If a future optional route needs an API key, store it in a user-level local config or environment variable, never in `shops.json` or committed files.
- Treat the key-based route as optional and separate from the default employee-local UI/WebDriver route.
- Keep its license boundary clear. auto-ziniao uses a personal/internal-use license, so use it for architectural reference only unless explicit permission is granted.

Do not make the current skill depend on this route:

- Do not require `ZCLAW_API_KEY` for normal employee use.
- Do not assume every company has the relevant Ziniao developer/assistant access enabled.
- Do not silently switch from employee-local browser context to a remote or developer-platform context.

## ziniao / ziniao-mcp CLI and MCP route

References:

- https://github.com/tianyehedashu/ziniao-mcp
- https://pypi.org/project/ziniao/

Useful ideas to keep:

- A CLI-first route can be easier for Codex than long-running services because the agent can run one explicit command and inspect stdout.
- MCP can be an optional adapter when the user has a Codex environment that exposes MCP tools but not direct terminal/browser control.
- Site presets, RPA flow files, artifacts and retry records are useful future concepts for repeatable seller workflows.

Do not make the current skill depend on this route:

- Do not require users to install `uv`, `ziniao`, or MCP for the default employee experience.
- Do not mix another tool's state/config directory with this package's ignored local files.
- Do not store credentials or browser session material in this repo.

## Generic browser automation skills

References:

- https://github.com/ComposioHQ/awesome-codex-skills
- https://github.com/clawdbot-ai/awesome-openclaw-skills-zh

Useful ideas to keep:

- Keep the skill small and route large details into references.
- Use deterministic scripts for fragile local setup, matching, diagnosis and shop opening.
- Use generic browser/visual automation only after the store is opened in the right local profile.
- Always separate safe navigation/reporting from destructive actions like publish, submit, spend, refund, delete, or settings changes.

## Product direction

Default scope for `ziniao-ops`:

1. Install skill and local helper scripts.
2. Launch/foreground Ziniao and wait for employee-local login.
3. Discover stores from the local Ziniao browser list.
4. Open the requested store and target module.
5. Read visible data and produce a concise report.
6. Optionally send the report through Feishu when the user explicitly asks.

Future optional tracks:

- `zclaw` route: optional Ziniao Assistant/OpenClaw key-based integration.
- `cdp-snapshot` route: after opening a store, use DevTools/DOM snapshots to extract tables and KPIs more reliably than screenshots.
- `report-pack` route: standardized Feishu/Markdown report templates for overview, ads, orders, finance and after-sale modules.
