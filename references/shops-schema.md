# shops.json schema

`shops.json` must stay local to the employee computer. In normal use it is a cache generated from the local Ziniao browser list by `scripts/sync-ziniao-shops.py`; manual editing is only for aliases, fixed view URLs, or special overrides.

Required top-level shape:

```json
{
  "version": 1,
  "updated_at": "2026-07-04",
  "source": "ziniao_detected",
  "shops": []
}
```

Each shop:

```json
{
  "name": "EXAMPLE_SHOPEE_MY",
  "platform": "shopee",
  "country": "my",
  "aliases": ["example shopee my", "example-my-sp"],
  "open_method": "ziniao_webdriver",
  "ziniao_name": "EXAMPLE_SHOPEE_MY",
  "browser_oauth": "",
  "browser_id": "",
  "allow_url_fallback": false,
  "detected_from": "ziniao_webdriver",
  "views": {
    "home": {"url": "https://..."},
    "overview": {"url": "https://..."},
    "orders": {"url": "https://..."},
    "products": {"url": "https://..."},
    "inventory": {"url": "https://..."},
    "ads": {"url": "https://..."},
    "marketing": {"url": "https://..."},
    "business": {"url": "https://..."},
    "traffic": {"url": "https://..."},
    "finance": {"url": "https://..."},
    "chat": {"url": "https://..."},
    "reviews": {"url": "https://..."},
    "vouchers": {"url": "https://..."},
    "campaigns": {"url": "https://..."},
    "livestream": {"url": "https://..."},
    "affiliate": {"url": "https://..."},
    "logistics": {"url": "https://..."},
    "returns": {"url": "https://..."},
    "compass": {"url": "https://..."},
    "dashboard": {"url": "https://..."},
    "discovery": {"url": "https://..."},
    "smax": {"url": "https://..."}
  },
  "open_command": ""
}
```

Rules:

- Never store password, token, browser session data or verification code.
- Store links only. The employee computer must already be logged in; this package must not contain login material.
- `source: "ziniao_detected"` means the file was generated from local Ziniao. Empty view URLs are allowed for these records; Codex should open the store environment first and navigate visually.
- `open_method`:
  - `ziniao_webdriver`: precise local Ziniao webdriver/API opening for Shopee and TikTok/Tokopedia.
  - `ziniao_gui`: precise local Ziniao GUI opening for Lazada.
  - `url`: normal browser URL fallback only.
  - `command`: custom local command.
- Use `browser_oauth` or `browser_id` only when the employee can safely identify the local Ziniao browser record. These are not passwords, but still keep them local.
- Use `ziniao_name` and `aliases` for matching local Ziniao account names.
- Use `open_command` only when the normal precision methods are not enough. It is disabled by default and requires `-AllowCommand`.
- `open_command` may contain placeholders: `{url}`, `{name}`, `{platform}`, `{view}`. Placeholders are inserted as PowerShell single-quoted literals, so write templates like `Start-Process {url}` instead of adding your own quotes around `{url}`. Only use it in a trusted local `shops.json`.
- Prefer `aliases` that employees naturally say to Codex.
- If one keyword matches multiple shops, ask for platform/country instead of guessing.
- `views` are target hints by default. The main script opens the precise local store first; it navigates to a view URL only when `-NavigateView` is passed.
- Supported generic view keys include `overview`, `orders`, `products`, `inventory`, `ads`, `marketing`, `business`, `traffic`, `finance`, `chat`, `reviews`, `vouchers`, `campaigns`, `livestream`, `affiliate`, `logistics` and `returns`. Platform-specific keys include `compass`, `dashboard`, `discovery` and `smax`.
- Missing requested view URLs must fail by default. Use `-AllowHomeFallback` only when opening `home` is acceptable.
