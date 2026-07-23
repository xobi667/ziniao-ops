# Store view intents

Use `View` as the target module hint after the store is opened through local Ziniao. A view does not guarantee that a fixed URL exists. For auto-detected Ziniao shops, empty URLs are normal; open the store environment first, then navigate visually.

Canonical views:

| View | User phrases | Visual target |
| --- | --- | --- |
| `home` | 打开店铺, 进入后台 | seller home page |
| `overview` | 全部数据, 全部情况, 整体情况, 总览, 概览 | main dashboard or first page with overall KPIs |
| `orders` | 订单, 出单, 待发货, 未发货 | order management |
| `products` | 商品, 产品, SKU, 刊登 | product/listing management |
| `inventory` | 库存, 仓库, 仓储 | inventory or stock page |
| `ads` | 广告, 投流, 投放, Shopee Ads | ads center/performance |
| `marketing` | 营销中心, 营销, 促销 | marketing center |
| `business` | 数据中心, 商业分析, 生意参谋, 经营分析, 运营数据 | analytics/business insights |
| `traffic` | 流量, 访客, 转化 | traffic/visitor analytics |
| `finance` | 财务, 钱包, 结算, 账单, 回款, 收款 | finance/wallet/settlement |
| `chat` | 客服, 聊天, 消息, 会话 | chat/message center |
| `reviews` | 评价, 评论, 星级, 差评 | review/rating management |
| `vouchers` | 优惠券, 折扣券 | voucher/coupon page |
| `campaigns` | 活动, 报名, 大促 | campaigns/promotions |
| `livestream` | 直播 | livestream tools |
| `affiliate` | 联盟, 达人, 分销 | affiliate/creator center |
| `logistics` | 物流, 发货, 履约, 运单, 面单 | shipping/fulfillment |
| `returns` | 售后, 退款, 退货, 退货退款 | return/refund/after-sale |
| `compass` | Compass, 罗盘, 数据罗盘 | TikTok/Tokopedia Compass |
| `dashboard` | dashboard, 看板, 仪表盘 | Lazada dashboard or generic dashboard |
| `discovery` | discovery, 推广发现 | Lazada discovery/promoted discovery |
| `smax` | 全效宝, Max 全站推广, SMAX | Lazada Sponsored Max |

Platform defaults:

- Shopee: prefer `business` for data center/business insights, `ads` for Shopee Ads, and the generic views for orders/products/finance/chat/reviews/logistics/returns.
- TikTok / Tokopedia: prefer `compass` for data overview, `ads` for ads, and generic views for operations modules.
- Lazada: prefer `dashboard` for main analytics, `discovery` and `smax` for sponsored solutions, and generic views for operations modules.

When the user asks for "全部数据" or "看这个店全部情况":

1. Open with `-View overview`.
2. Read the visible summary/dashboard KPIs first.
3. If the user needs more detail, drill into the relevant modules one by one (`orders`, `ads`, `business`, `finance`, etc.).
4. Do not click actions that create, submit, publish, spend money, change products, or modify settings.

When the exact platform label differs, use semantic visual navigation. For example, "经营分析" can appear as Business Insights, Data Center, Business Advisor, Analytics, Compass, or Dashboard depending on platform and country.
