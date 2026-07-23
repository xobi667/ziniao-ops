# Upstream Tracking

Own repository:

- Name: `xobi667/ziniao-ops`
- Git URL: `https://github.com/xobi667/ziniao-ops.git`
- Skill name: `ziniao-ops`

Run this before reviewing upstream changes:

```powershell
.\scripts\check-upstreams.ps1
```

Clone or update Git-based upstream mirrors into ignored `.upstreams/`:

```powershell
.\scripts\sync-upstreams.ps1
```

Check optional upstream adapters on the current computer:

```powershell
.\scripts\status-upstream-adapters.ps1
```

Install or refresh optional upstream commands on the current computer:

```powershell
.\scripts\install-upstream-tools.ps1
```

For machine-readable output:

```powershell
.\scripts\check-upstreams.ps1 -Json
```

The script checks GitHub remotes with `git ls-remote` and reports the latest commit for each tracked branch. Non-Git docs, such as PyPI and official Ziniao docs, are listed for manual review.

`sync-upstreams.ps1` clones Git-based upstreams into `.upstreams/` and writes `.upstreams/upstreams.status.json`. That folder is local-only and ignored by Git.

Browser control is not supplied by an upstream mirror. Codex CLI and Codex IDE both use the Codex built-in Browser by default; see [codex-browser.md](codex-browser.md). Generic browser MCP repositories are not tracked, installed, or synchronized.

## Review Rules

- Do not auto-merge upstream code.
- Read each upstream license before copying code. `WW-AI-Lab/auto-ziniao` is recorded as architecture reference only because its license is personal/internal-use, not a permissive open-source license.
- Keep `ziniao-ops` default install simple: no required LLM key, no required `ZCLAW_API_KEY`, no long-running WebAdmin service, no credential storage.
- Bring in only small, compatible ideas that strengthen the employee-local workflow: store matching, local browser isolation, diagnostics, report shape, safer popup handling, and optional CLI adapters.
- Use the Codex built-in Browser for normal page control. Keep purpose-built local CDP/UIA code only as an explicit legacy fallback for a user-requested Ziniao/Xinjian local context.
- Update `references/external-projects.md` when adopting a concept, and run `scripts/validate-public.ps1` before publishing.
- For exact adapter status and command examples, read [upstream-integration.md](upstream-integration.md).

## Tracked Sources

| Upstream | Branch | Why track it | Adoption boundary |
| --- | --- | --- | --- |
| `tianyehedashu/ziniao-mcp` | manual | CLI commands, site presets, RPA flows, skill installer ideas | CLI-only reference; do not install or start its MCP server |
| PyPI `ziniao` | manual | Published CLI package docs and install command | Documentation reference only |
| `zpoint/vibe-seller` | `main` | Local-first seller browser automation, store isolation, CDP/browser control, task reports | Borrow concepts; keep `ziniao-ops` lightweight |
| `WW-AI-Lab/auto-ziniao` | `develop` | ZClaw bridge boundary, flow validation, WebAdmin/self-heal concepts | Architecture reference only unless permission is granted |
| `ComposioHQ/awesome-codex-skills` | `master` | Codex skill packaging and ecosystem patterns | Track packaging ideas only |
| `clawdbot-ai/awesome-openclaw-skills-zh` | manual | Chinese skill wording and user-facing install patterns | Manual review only; current Git URL is not reliably accessible |
| Ziniao Open Platform docs | manual | Official Ziniao platform/assistant docs | Prefer official docs for future ZClaw support |
