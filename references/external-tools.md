# External Tool Catalog

Use this when the user asks whether to install LinkFox, Seller Sprite, review-insight, creative, market-research, or self-improving agent tools.

Machine-readable config lives in `references/external-tools.json`.

For the broader ecommerce platform/API/tool map, use `references/ecommerce-capability-map.md` and `references/ecommerce-capability-map.json`.

## Decision Rules

- Do not silently install closed SaaS tools, paid tools, browser extensions, or third-party skills.
- Do not upload seller screenshots, store names, cookies, sessions, tokens, or private reports to external tools unless the user explicitly asks and the target account boundary is clear.
- Treat external tools as optional routes:
  - LinkFox Agent: market and competitor research.
  - LinkFox AI: creative/image/video generation.
  - Amazon Reviews: Amazon review and customer-pain analysis.
  - Seller Sprite: Amazon product/keyword/ads/profit research through official API or MCP.
  - LinkFox Skills: optional skill marketplace, not a dependency of this package.
  - Self Improving Agent: useful design idea; keep local learning logs private by default.

## Update Checking

Run:

```powershell
.\scripts\check-external-tools.ps1
```

JSON output:

```powershell
.\scripts\check-external-tools.ps1 -Json
```

The script checks official URLs and extracts known LinkFox skill versions when the catalog page is reachable. It does not install or auto-update paid/SaaS tools.

## Better Default For ziniao-ops

The default path should remain local:

1. Open the employee's local Ziniao store.
2. Navigate seller modules visually and safely.
3. Generate local read-only task plans/reports.
4. Use external tools only when the task is outside local store operations, such as Amazon market research, review mining, or creative generation.
