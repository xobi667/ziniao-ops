# GitHub release checklist

Before pushing or publishing a zip:

1. Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-public.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-upstreams.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\status-upstream-adapters.ps1
```

2. Confirm these files are not present in the public package:

- `shops.json`
- `shops.detected.json`
- `shops.local.json`
- `shops.private.json`
- `ziniao.local.json`
- `.env`
- logs, screenshots, Excel exports, zip files

3. Test the public install flow from a clean extracted folder:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

The interactive installer must ask where local dependencies should be installed when GUI/upstream tools are selected. On machines with a small C drive, choose a D/E drive path:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -NonInteractive -InstallLazadaDeps -InstallOptionalTools -InstallMissingRuntimes -LocalToolsRoot "D:\ziniao-ops-tools"
```

If the test machine cannot complete Ziniao login during install, use:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -SkipZiniaoSetup
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup-ziniao.ps1
```

4. On an employee Windows machine with Ziniao logged in, test:

```powershell
.\setup-ziniao.ps1
.\open-shop.ps1 -List -RefreshZiniao
.\open-shop.ps1 "<店铺关键词>" -View overview -DryRun -Json
.\open-shop.ps1 "<店铺关键词>" -View orders -DryRun -Json
.\open-store.ps1 "<店铺关键词>" -View overview -LoginTimeoutSeconds 60 -Json
.\scripts\new-ops-task.ps1 -Store "<店铺关键词>" -Intent "巡店日报" -Platform shopee -Json
.\scripts\new-ops-batch.ps1 -Store "<店铺关键词>" -Workflow daily_check -Json
.\scripts\new-ops-report.ps1 -Store "<店铺关键词>" -Platform shopee -Workflow daily_check -MetricsJson "{}" -Json
```

5. The release description should tell users:

- Release name: `ziniao-ops v0.1.0-beta` or newer.
- This is not an official Ziniao product.
- Download and extract the zip.
- Run `install.ps1`; it will install the skill and run the Ziniao readiness check.
- `install.ps1` checks required runtimes, asks for a local dependency directory, installs GUI dependencies locally, and can install optional upstream tools.
- If Ziniao asks for login or verification, complete it locally in the Ziniao window.
- If setup was skipped or timed out, run `setup-ziniao.ps1`.
- Restart Codex.
- Ask Codex to open the store. Codex should use `open-store.ps1` so login handoff and store opening happen in one command.
- For store operations beyond opening, Codex can generate read-only tasks with `new-ops-task.ps1`, batch checklists with `new-ops-batch.ps1`, and reports with `new-ops-report.ps1`.
- Sending reports to Feishu/Lark must be an explicit action after confirming the target chat/user.
- Similar projects exist, including Vibe Seller, auto-ziniao/OpenClaw, and ziniao/ziniao-mcp routes, but this package is the lightweight Codex skill route and does not require storing Ziniao passwords or `ZCLAW_API_KEY`.
- Upstream tracking is recorded in `references/upstreams.md` and `references/upstreams.json`; use `scripts/check-upstreams.ps1` before cutting a release.
- Optional upstream adapter status is documented in `references/upstream-integration.md`. `.upstreams/` is local-only and must not be included in release zips.

Do not include passwords, verification codes, browser session data, app tokens, real store lists, or local machine paths in the release.
