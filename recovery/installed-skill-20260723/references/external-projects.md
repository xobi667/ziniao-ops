# External project references

This package is a lightweight Codex skill for employee-local Ziniao store opening and operations-page navigation. It is not an official Ziniao product and does not vendor code from the projects below. Web-page interaction in both Codex CLI and Codex IDE uses the Codex built-in Browser by default; see [codex-browser.md](codex-browser.md).

Tracked upstream names, URLs and branch notes live in [upstreams.md](upstreams.md) and [upstreams.json](upstreams.json). Use `scripts/check-upstreams.ps1` from the repo root before reviewing upstream changes.
Exact feature status, optional adapters, and sync commands live in [upstream-integration.md](upstream-integration.md).

## Vibe Seller

Reference: https://github.com/zpoint/vibe-seller

Useful ideas to keep:

- Local-first seller automation: store data, logs, screenshots and memories should stay on the employee's machine unless the user explicitly sends a report elsewhere.
- Store isolation: each task must target one matched local Ziniao store/browser profile; do not cross-use another store's browser or data.
- Browser-control preference: after opening the store environment, use the Codex built-in Browser for visible navigation, DOM-backed interaction, and screenshots in both CLI and IDE. Local CDP or foreground visual UI is not an automatic fallback; use it only after the user explicitly authorizes the corresponding legacy local route.
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

## `ziniao` CLI route

References:

- https://github.com/tianyehedashu/ziniao-mcp
- https://pypi.org/project/ziniao/

Useful ideas to keep:

- A CLI command is useful for deterministic local store scanning, matching, and startup because Codex can inspect its structured output.
- Site presets, RPA flow files, artifacts and retry records are useful future concepts for repeatable seller workflows.

Do not make the current skill depend on this route:

- Do not require users to install `uv` or `ziniao` for the default employee experience.
- Do not start or recommend the upstream MCP server. The optional wrapper is CLI-only and must stop after store scanning, matching, or startup; visible page interaction belongs to the Codex built-in Browser.
- Do not mix another tool's state/config directory with this package's ignored local files.
- Do not store credentials or browser session material in this repo.

## Codex built-in Browser

Useful ideas to keep:

- Use `browser:control-in-app-browser` as the default web interaction surface whenever it is available in the current Codex CLI or Codex IDE session.
- Respect an explicit user choice of Browser and do not substitute another browser-control route.
- Prefer accessibility/DOM snapshots and stable element references over screenshot-only reading when extracting tables and KPIs.
- Keep the skill small and route large details into references.
- Use deterministic scripts for fragile local setup, matching, diagnosis and shop opening.
- After the correct store environment is selected, use the built-in Browser for navigation, visible-data reading, clicking, typing, and screenshots.
- Always separate safe navigation/reporting from destructive actions like publish, submit, spend, refund, delete, or settings changes.

Adoption boundaries:

- Do not install, synchronize, recommend, or invoke generic browser MCP servers. The Codex built-in Browser is supplied by the Codex runtime and is not a dependency installed by this package.
- Do not claim the built-in Browser inherits a Ziniao browser session. If login is required, the user completes it manually in the selected Browser; never copy cookies, tokens, profiles, or session directories.
- Direct local CDP/UIA or temporary Edge bridges are explicit legacy fallbacks only for a user-requested Ziniao/Xinjian local context that the built-in Browser cannot access. They are not a default browser route.
- auto-ziniao is not permissively licensed; keep it as architecture reference only.
- 心舰 ERP uses the built-in Browser for normal page interaction and the local export analyzer for deterministic report validation.

## Product direction

Default scope for `ziniao-ops`:

1. Install skill and local helper scripts.
2. Discover and start the requested employee-local Ziniao store through local scripts or the optional `ziniao` CLI.
3. Use the Codex built-in Browser for the target web page in CLI and IDE.
4. Read visible data and produce a concise report.
5. Require explicit confirmation for any write, spend, submit, refund, delete, or settings action.
6. Optionally send the report through Feishu when the user explicitly asks.

Future optional tracks:

- `zclaw` route: optional Ziniao Assistant/OpenClaw key-based integration.
- `legacy-local-cdp` route: only after explicit user selection, reuse an existing Ziniao/Xinjian local debug context when the built-in Browser cannot access it.
- `report-pack` route: standardized Feishu/Markdown report templates for overview, ads, orders, finance and after-sale modules.
