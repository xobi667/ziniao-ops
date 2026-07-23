# Visual popup handling

Use this after the local store environment opens.

Rules:

- Use the visible active store window; do not depend on a fixed window title or hardcoded coordinates.
- Close only blocking popups, tutorials, ads, surveys, announcements, consent banners and upgrade prompts.
- Safe buttons/texts include:
  - Chinese: `关闭`, `跳过`, `稍后`, `以后再说`, `我知道了`, `知道了`, `不再提示`, `暂不`, `取消`
  - English: `Close`, `Skip`, `Later`, `Not now`, `Got it`, `No thanks`, `Maybe later`
  - Thai/Indonesian equivalents may be clicked only when the layout clearly means close/skip/later.
- Prefer the top-right `X` on modal dialogs.
- Do not click buttons that create, submit, publish, spend budget, confirm payment, change ads, change products, or modify settings.
- If a popup blocks the target navigation and there is no safe close/skip option, stop and ask the employee.

Target page hints:

- Shopee ads: click marketing/ads entries, or use the existing visible seller navigation.
- Shopee business: click business insights / data center.
- TikTok/Tokopedia ads: click ads or marketing center.
- TikTok/Tokopedia compass: click data/Compass.
- Lazada dashboard/discovery/smax: use seller center navigation after closing blocking popups.
- Generic operations modules: orders, products, inventory, finance, chat, reviews, vouchers, campaigns, livestream, affiliate, logistics and returns should be reached through the visible seller navigation/search. Prefer labels with the same business meaning over fixed coordinates.
- For `overview` or "全部数据", read the visible dashboard summary first. Do not pretend every module has been inspected unless you actually opened those modules.
