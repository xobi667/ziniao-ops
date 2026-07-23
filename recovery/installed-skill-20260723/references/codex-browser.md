# Codex Built-in Browser Route

Use this reference for every task that needs to open or navigate a web page, inspect visible or interactive state, click, type, take a screenshot, or verify a web UI.

## One Default in CLI and IDE

Codex CLI and Codex IDE follow the same browser policy:

1. When the current session provides `browser:control-in-app-browser`, use the Codex built-in Browser as the default web interaction surface.
2. If the user explicitly asks for the Codex Browser or in-app Browser, that choice wins for the task.
3. Reuse the selected Browser and its existing tab when it still serves the task; do not open duplicate tabs without a reason.
4. If the built-in Browser is unavailable, report that blocker. Do not install, configure, or invoke a generic browser MCP as a substitute.

The built-in Browser is a Codex runtime capability. It is not an npm package, Chrome extension, external server, or dependency installed by `ziniao-ops`. Repository instructions must not expose or depend on its internal transport implementation.

## Responsibility Split

Use the narrowest component for each job:

- `ziniao` CLI: local Ziniao store scanning, deterministic matching, and store-environment startup only.
- Built-in PowerShell/WebDriver helpers: local store discovery/startup fallback and deterministic diagnostics only.
- Codex built-in Browser: web navigation, visible-data inspection, DOM/accessibility reading, clicking, typing, screenshots, and UI-state verification.
- Export watcher/analyzer: validate downloaded reports, date/store coverage, hashes, calculations, and generated deliverables.

Do not use the `ziniao` CLI as a general page reader or browser automation surface. Once the correct store environment or target URL is known, normal web interaction belongs to the built-in Browser.

## No Generic Browser MCP Route

This package does not install, synchronize, recommend, or invoke BrowserMCP, Chrome DevTools MCP, Playwright MCP, or another generic browser-control MCP server. These tools are not a default, optional fallback, upstream mirror, or troubleshooting recommendation.

If an old installation still contains one of those packages or config keys, treat it as deprecated local state. Remove only the verified package entry or obsolete key; never delete an entire npm prefix, browser profile, or local state directory as a shortcut.

## Authentication Boundary

The Codex built-in Browser does not automatically inherit a Ziniao browser profile or its login state. If the selected page requires login:

- Keep that Browser page open and ask the employee to sign in manually there.
- Never request passwords or verification codes in chat.
- Never read, copy, print, or reuse cookies, localStorage, tokens, browser profiles, or session directories.
- Do not switch browsers merely to bypass authentication unless the user explicitly approves the switch.

## Explicit Legacy Local-Context Fallback

Purpose-built local CDP/UIA scripts and the temporary Edge login bridge are not MCP, but they are still legacy compatibility routes. Use one only when all of the following are true:

- The user explicitly asks to reuse a particular Ziniao/Xinjian local browser context, or confirms the legacy fallback after the built-in Browser cannot serve that context.
- The task genuinely depends on that employee-local browser session or a purpose-built local diagnostic.
- The action stays within the login and write-safety boundaries.

Legacy behavior must be fail-closed:

- Probe existing local pages without opening another browser first.
- Do not automatically launch a temporary Edge/Chrome profile when the built-in Browser route fails.
- Do not copy session material into the built-in Browser or temporary profile.
- Return a clear blocker when no approved, controllable local page exists.

## Action and Evidence Rules

- Read-only navigation and inspection may proceed through the built-in Browser.
- Publishing, submitting, changing prices or ad budgets, sending messages, refunds, payments, deletion, and settings changes require explicit confirmation for the exact action.
- A detected window, Browser availability check, route map, or remembered button is not business-data evidence by itself.
- Report figures as verified only when the workflow's required page interaction and data-source evidence are both present.
