# Lark CLI shop list refresh

Use this only when the employee asks to supplement the local Ziniao-detected shop cache with Feishu/Lark or a CSV exported from another authorized source. Normal store discovery should come from this computer's local Ziniao browser list.

Principles:

- Use the employee computer's own `lark-cli` identity.
- Do not log or store app tokens, user tokens, browser session data or verification codes.
- Do not modify Feishu data for this workflow; read/export only.
- Convert Feishu rows into local `<package_root>\shops.json` only when local Ziniao detection is insufficient or fixed view URLs/aliases are needed.

Expected fields from Feishu or exported CSV:

- `name` or `店铺名称`
- `platform` or `平台`
- `country` or `国家`
- `aliases` or `别名`
- `ziniao_name` or `紫鸟店铺名`
- optional `browser_oauth` / `browser_id` for Shopee/TikTok precision matching
- optional view URLs such as `overview_url`, `orders_url`, `products_url`, `inventory_url`, `ads_url`, `business_url`, `traffic_url`, `finance_url`, `chat_url`, `reviews_url`, `vouchers_url`, `campaigns_url`, `livestream_url`, `affiliate_url`, `logistics_url`, `returns_url`, `compass_url`, `dashboard_url`, `discovery_url`, `smax_url`, and matching Chinese headers like `广告页URL`, `订单URL`, `财务URL`, `客服URL`

If Feishu Base/table IDs are not already configured on that employee machine, ask the data administrator for the correct source or use an exported CSV/JSON file. Do not hardcode secrets in this package.

If a CSV export is available, import it with:

```powershell
$codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE ".codex" }
$cfg = Get-Content (Join-Path $codexHome "ziniao-ops.json") -Raw | ConvertFrom-Json
powershell -ExecutionPolicy Bypass -File (Join-Path $cfg.package_root "scripts\import-shops-csv.ps1") (Join-Path $cfg.package_root "shops.csv")
```

The import script accepts Chinese or English headers for shop name, platform, country, aliases, Ziniao name, optional browser IDs and common view URLs, including both `链接` and `URL` suffixes. It automatically assigns `ziniao_webdriver` to Shopee/TikTok and `ziniao_gui` to Lazada unless an `open_method` column is provided.
