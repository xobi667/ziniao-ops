# Ecommerce capability map

Use this reference when the user asks what `ziniao-ops` can do beyond opening a store, what ecommerce tools are missing, or which outside systems should be connected next.

Machine-readable config lives in `references/ecommerce-capability-map.json`.

## Plain answer

`ziniao-ops` is now positioned as a local seller-ops control layer:

1. Open the employee's own local Ziniao store browser.
2. Guide read-only store operations: overview, orders, products, inventory, ads, marketing, analytics, finance, chat, reviews, logistics, returns.
3. Generate local task plans and reports.
4. Track optional ecommerce tools and official platform APIs.
5. Keep paid SaaS, external accounts, API credentials, and MCP setup explicit.

It is not a bundled all-in-one SaaS. Third-party tools are cataloged and health-checked, not silently installed.

## P0 gaps to build next

- Official platform API data layer: Amazon SP-API, Amazon Ads API, Shopee Open Platform, TikTok Shop API, Lazada Open Platform.
- Normalized ecommerce entities: store, product, SKU, order, shipment, return/refund, review, message, ad campaign, finance settlement, competitor product, keyword, report.
- More read-only operations templates: store health, ads anomalies, inventory warnings, refund/after-sale risk, customer-service timeout, bad-review monitoring, listing violation warnings, finance payout anomalies.

## Optional tools by job

Market and competitor research:

- Seller Sprite
- Keepa
- Jungle Scout
- Helium 10
- DataHawk
- LinkFox Agent

Reviews and voice of customer:

- Amazon Reviews
- VOC.AI
- Shulex VOC

Creative production:

- LinkFox AI
- Creatify
- Canva Developers

Ads and growth:

- Amazon Ads API
- Pacvue
- Perpetua

Customer service:

- Gorgias

Logistics:

- ShipStation
- Shippo
- AfterShip

Finance, tax, and profit:

- TaxJar
- Avalara AvaTax

ERP and multichannel:

- Rithum / ChannelAdvisor
- Linnworks
- Sellercloud

Repricing:

- Seller Snap
- Feedvisor
- StreetPricer

## Check current catalog

Run:

```powershell
.\scripts\check-ecommerce-tools.ps1
```

JSON output:

```powershell
.\scripts\check-ecommerce-tools.ps1 -Json
```

Filter one category:

```powershell
.\scripts\check-ecommerce-tools.ps1 -Category market_research
.\scripts\check-ecommerce-tools.ps1 -Category logistics_and_fulfillment
.\scripts\check-ecommerce-tools.ps1 -Category official_platform_api -TimeoutSec 1 -TotalTimeoutSec 20 -MaxConcurrency 8
```

The script checks official URLs and docs pages. It does not install paid tools, create accounts, submit store data, or update external SaaS.

## Decision rule

Default to local Ziniao operations for employee store work. Use outside tools only when the request is outside local seller-center operation, such as market research, Amazon reviews, creative generation, logistics tracking, tax, multichannel ERP, or repricing.
