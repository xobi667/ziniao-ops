# Platform API roadmap

Use this when the user asks how `ziniao-ops` should become a real ecommerce operations layer instead of only a local Ziniao opener.

## Principle

Start read-only. Do not store credentials in Git. Do not ask users to paste secrets into chat. Local optional API configuration must live under ignored local state, such as `.ziniao-ops\integrations.local.json`, or environment variables on the employee machine.

## Phase 0: current local layer

Already included:

- Open local Ziniao store environments.
- Reuse the current Ziniao/store window when possible.
- Route user phrases to seller modules.
- Generate local read-only task plans and reports.
- Track optional upstream projects and external ecommerce tools.

## Phase 1: credential readiness detector

Add a detector that reports only:

- Which connector config files exist.
- Which required fields are present or missing.
- Which scopes are read-only vs write-capable.
- Whether a test request can reach the official API.

It must never print secrets or raw auth headers.

## Phase 2: read-only connectors

Build connectors in this order:

1. Shopee Open Platform: shop, order, listing, marketing, chat data.
2. TikTok Shop API: shops, products, orders, shipments, payments.
3. Lazada Open Platform: products, inventory, orders, finance, sponsored solutions.
4. Amazon SP-API: orders, shipments, payments, catalog, inventory, reports.
5. Amazon Ads API: campaigns, keywords, ads, reports.
6. Shopify Admin GraphQL API and BigCommerce APIs for non-marketplace stores.

## Phase 3: normalized local reports

Write all connector outputs into a common local model:

- `store`
- `product`
- `sku`
- `inventory`
- `order`
- `shipment`
- `return_refund`
- `review`
- `customer_message`
- `ad_campaign`
- `finance_settlement`
- `ops_report`

Reports should compare visible seller-center data, platform API data, and optional third-party data only when those sources are explicitly configured.

## Phase 4: gated write actions

Do not start here. These are high-risk:

- Product publishing
- Price changes
- Inventory edits
- Ad budget or bid changes
- Customer messages
- Refunds and returns
- Payment or tax submissions

Each write action needs a separate connector design, dry-run mode, confirmation prompt, audit log, and rollback notes where the platform supports it.

## Official docs to track

- Amazon SP-API: `https://developer.amazonservices.com/`
- Amazon Ads API: `https://advertising.amazon.com/API/docs`
- Shopee Open Platform: `https://open.shopee.com/`
- TikTok Shop Partner Center docs: `https://partner.tiktokshop.com/docv2/page/tts-developer-guide`
- Lazada Open Platform: `https://open.lazada.com/`
- Shopify Admin GraphQL API: `https://shopify.dev/docs/api/admin-graphql/latest`
- BigCommerce APIs: `https://docs.bigcommerce.com/`

Check catalog status with:

```powershell
.\scripts\check-ecommerce-tools.ps1 -Json
```
