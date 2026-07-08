# Xinjian UI Action Catalog

Generated from sanitized public 心舰 UI maps. Use this as a compact index of remembered pages, buttons, filters, overlays, dialogs, row actions, safety gates, and locator strategies.

## Totals

- Pages: 49
- Actions: 529
- Global actions: 6

### Sources

| Source | Version | Pages | Actions |
| --- | --- | ---: | ---: |
| curated | 2026-07-08.2 | 10 | 63 |
| auto | 2026-07-08 | 38 | 327 |
| overlay | 2026-07-08 | 26 | 162 |
| dialog | 2026-07-08 | 8 | 35 |
| row-action | 2026-07-08 | 1 | 2 |

### Safety

| Safety mode | Actions |
| --- | ---: |
| confirmation_required_export | 8 |
| confirmation_required_write | 138 |
| manual_review | 9 |
| safe_execute_allowed | 374 |

### Locator Strategies

| Locator strategy | Actions |
| --- | ---: |
| click_first_matching_row_action_in_table | 2 |
| click_quick_tab_text_or_placeholder_list | 3 |
| click_trigger_selector | 71 |
| click_trigger_selector_then_dialog_button_text | 26 |
| click_trigger_selector_then_overlay_item_text | 40 |
| click_visible_action_text | 50 |
| click_visible_dom_text | 213 |
| click_visible_tab_text_from_list | 1 |
| input_or_filter_placeholder | 67 |
| input_or_filter_placeholder_list | 2 |
| navigate_href | 43 |
| row_context_required_column_header | 2 |
| uia_locator | 9 |

## Audit

- Manual-review actions: 9
- Map-only actions: 0
- Empty-locator actions: 0

### Manual Review Actions

| Page | Route | Action | Type | Strategy | Purpose |
| --- | --- | --- | --- | --- | --- |
| 收藏夹详情 | `/crm/favorite/detail` | 群发邮件 | button | click_visible_dom_text | Observed 群发邮件 control on 收藏夹详情; exact behavior has not been clicked yet. |
| 发起 OA 请假 | `/bpm/oa/leave/create` | 请输入原因 | form_input | input_or_filter_placeholder | Fill or choose the 请输入原因 field on 发起 OA 请假; submitting the form still requires explicit confirmation. |
| 发起 OA 请假 | `/bpm/oa/leave/create` | 选择结束时间 | form_input | input_or_filter_placeholder | Fill or choose the 选择结束时间 field on 发起 OA 请假; submitting the form still requires explicit confirmation. |
| 发起 OA 请假 | `/bpm/oa/leave/create` | 选择开始时间 | form_input | input_or_filter_placeholder | Fill or choose the 选择开始时间 field on 发起 OA 请假; submitting the form still requires explicit confirmation. |
| 黑名单管理 | `/erp/blacklist` | 自动加黑 | button | click_visible_dom_text | Observed 自动加黑 control on 黑名单管理; exact behavior has not been clicked yet. |
| SKU最低售价配置 | `/order/sku-min-price` | 新增选择 | dialog_button | click_trigger_selector_then_dialog_button_text | Use 选择 inside the 新增 dialog/drawer on SKU最低售价配置. |
| 首页 | `/index/home` | 店铺 | overlay_item | click_trigger_selector_then_overlay_item_text | Choose 店铺 from the 请选择 overlay on 首页. |
| 首页 | `/index/home` | 订单 | overlay_item | click_trigger_selector_then_overlay_item_text | Choose 订单 from the 请选择 overlay on 首页. |
| 首页 | `/index/home` | 利润 | overlay_item | click_trigger_selector_then_overlay_item_text | Choose 利润 from the 请选择 overlay on 首页. |

## ADS / 广告详情

- Route: `/ad/group-detail`
- Sources: curated, dialog
- Actions: 7

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 切换币种 | text:切换币种 | button | safe_execute_allowed | click_visible_dom_text | curated | Switch the displayed currency for ad detail metrics. |
| 修改 | text:修改 | button | confirmation_required_write | click_visible_dom_text | curated | Open an edit flow for ad detail settings such as bid-related fields. Requires explicit confirmation before saving. |
| 日期范围 | tabs:今天/昨天/近7天/近30天; placeholders:开始日期/结束日期 | date_filter | safe_execute_allowed | click_quick_tab_text_or_placeholder_list | curated | Set the ad detail date range or use the visible quick tabs. |
| 修改关闭 | 修改 -> 关闭 | dialog_button | safe_execute_allowed | click_trigger_selector_then_dialog_button_text | dialog | Use 关闭 inside the 修改 dialog/drawer on 广告详情. |
| 修改取消 | 修改 -> 取消 | dialog_button | safe_execute_allowed | click_trigger_selector_then_dialog_button_text | dialog | Use 取消 inside the 修改 dialog/drawer on 广告详情. |
| 修改确定 | 修改 -> 确定 | dialog_button | confirmation_required_write | click_trigger_selector_then_dialog_button_text | dialog | Use 确定 inside the 修改 dialog/drawer on 广告详情. |
| 修改 |  | dialog_opener | safe_execute_allowed | click_trigger_selector | dialog | Open the 修改 dialog/drawer on 广告详情; do not submit changes without explicit confirmation. |

## ADS / 创意详情

- Route: `/ad/originality-detail`
- Sources: curated, overlay
- Actions: 19

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 应用 | text:应用 | batch_action | confirmation_required_write | click_visible_dom_text | curated | Apply the selected batch operation to selected creative records. Requires explicit confirmation. |
| 切换币种 | text:切换币种 | button | safe_execute_allowed | click_visible_dom_text | curated | Switch the displayed currency for creative detail metrics. |
| 重置 | text:重置 | button | safe_execute_allowed | click_visible_dom_text | curated | Clear current creative-detail filters. |
| 日期范围 | tabs:今天/昨天/近7天/近30天; placeholders:开始日期/结束日期 | date_filter | safe_execute_allowed | click_quick_tab_text_or_placeholder_list | curated | Set the creative detail date range or use the visible quick tabs. |
| 创意状态 | placeholder:请选择创意状态 | filter_dropdown | safe_execute_allowed | input_or_filter_placeholder | curated | Filter ad creatives by creative status. |
| 搜索内容 | placeholder:请输入搜索内容 | filter_input | safe_execute_allowed | input_or_filter_placeholder | curated | Search within creative detail records. |
| 按视频名称 | 请选择 -> 按视频名称 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 按视频名称 from the 请选择 overlay on 创意详情. |
| 按视频ID号 | 请选择 -> 按视频ID号 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 按视频ID号 from the 请选择 overlay on 创意详情. |
| 按Tiktok账号 | 请选择 -> 按Tiktok账号 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 按Tiktok账号 from the 请选择 overlay on 创意详情. |
| 批量按视频名称 | 选择批量操作 -> 按视频名称 | overlay_item | confirmation_required_write | click_trigger_selector_then_overlay_item_text | overlay | Choose 按视频名称 from the 选择批量操作 overlay on 创意详情. |
| 批量按视频ID号 | 选择批量操作 -> 按视频ID号 | overlay_item | confirmation_required_write | click_trigger_selector_then_overlay_item_text | overlay | Choose 按视频ID号 from the 选择批量操作 overlay on 创意详情. |
| 批量按Tiktok账号 | 选择批量操作 -> 按Tiktok账号 | overlay_item | confirmation_required_write | click_trigger_selector_then_overlay_item_text | overlay | Choose 按Tiktok账号 from the 选择批量操作 overlay on 创意详情. |
| 批量排除 | 请选择 -> 批量排除 | overlay_item | confirmation_required_write | click_trigger_selector_then_overlay_item_text | overlay | Choose 批量排除 from the 请选择 overlay on 创意详情. |
| 批量排除 | 选择批量操作 -> 批量排除 | overlay_item | confirmation_required_write | click_trigger_selector_then_overlay_item_text | overlay | Choose 批量排除 from the 选择批量操作 overlay on 创意详情. |
| 批量添加至广告计划 | 选择批量操作 -> 添加至广告计划 | overlay_item | confirmation_required_write | click_trigger_selector_then_overlay_item_text | overlay | Choose 添加至广告计划 from the 选择批量操作 overlay on 创意详情. |
| 添加至广告计划 | 请选择 -> 添加至广告计划 | overlay_item | confirmation_required_write | click_trigger_selector_then_overlay_item_text | overlay | Choose 添加至广告计划 from the 请选择 overlay on 创意详情. |
| 请选择 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择 overlay on 创意详情. |
| 请选择创意状态 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择创意状态 overlay on 创意详情. |
| 选择批量操作 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 选择批量操作 overlay on 创意详情. |

## ADS / 店铺广告分析

- Route: `/ad/shop-detail`
- Sources: curated, dialog, overlay
- Actions: 19

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 切换币种 | text:切换币种 | button | safe_execute_allowed | click_visible_dom_text | curated | Switch the displayed currency for advertising metrics. |
| 预警设置 | text:预警设置 | button | confirmation_required_write | click_visible_dom_text | curated | Open advertising balance warning settings. Requires explicit confirmation before saving changes. |
| 重置 | text:重置 | button | safe_execute_allowed | click_visible_dom_text | curated | Clear current shop advertising analysis filters. |
| 日期范围 | tabs:今天/昨天/近7天/近30天; placeholders:开始日期/结束日期 | date_filter | safe_execute_allowed | click_quick_tab_text_or_placeholder_list | curated | Set the advertising analysis date range or use the visible quick tabs. |
| 预警设置关闭 | 预警设置 -> 关闭 | dialog_button | safe_execute_allowed | click_trigger_selector_then_dialog_button_text | dialog | Use 关闭 inside the 预警设置 dialog/drawer on 店铺广告分析. |
| 预警设置取消 | 预警设置 -> 取消 | dialog_button | safe_execute_allowed | click_trigger_selector_then_dialog_button_text | dialog | Use 取消 inside the 预警设置 dialog/drawer on 店铺广告分析. |
| 预警设置确定 | 预警设置 -> 确定 | dialog_button | confirmation_required_write | click_trigger_selector_then_dialog_button_text | dialog | Use 确定 inside the 预警设置 dialog/drawer on 店铺广告分析. |
| 预警设置 |  | dialog_opener | safe_execute_allowed | click_trigger_selector | dialog | Open the 预警设置 dialog/drawer on 店铺广告分析; do not submit changes without explicit confirmation. |
| 选择店铺 | placeholder:选择店铺 | filter_input | safe_execute_allowed | input_or_filter_placeholder | curated | Filter shop-level advertising analysis by shop. |
| 按店铺 | 请选择 -> 按店铺 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 按店铺 from the 请选择 overlay on 店铺广告分析. |
| 按店铺 | 选择店铺 -> 按店铺 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 按店铺 from the 选择店铺 overlay on 店铺广告分析. |
| 按负责人 | 请选择 -> 按负责人 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 按负责人 from the 请选择 overlay on 店铺广告分析. |
| 按负责人 | 选择店铺 -> 按负责人 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 按负责人 from the 选择店铺 overlay on 店铺广告分析. |
| 按人员 | 请选择 -> 按人员 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 按人员 from the 请选择 overlay on 店铺广告分析. |
| 按人员 | 选择店铺 -> 按人员 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 按人员 from the 选择店铺 overlay on 店铺广告分析. |
| 请选择 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择 overlay on 店铺广告分析. |
| 选择店铺 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 选择店铺 overlay on 店铺广告分析. |
| 行分析 | column:分析 | row_navigation | safe_execute_allowed | row_context_required_column_header | curated | Open a row-level advertising analysis/detail page for the selected shop or ad entity. |
| 平台标签 | tabs:Shopee/Lazada/Tiktok | tab | safe_execute_allowed | click_visible_tab_text_from_list | curated | Switch the shop advertising analysis table between platform tabs. |

## ADS / 广告规则执行日志

- Route: `/erp/ads/rule-log`
- Sources: curated, overlay
- Actions: 10

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 导出日志 | text:导出日志 | button | confirmation_required_export | click_visible_dom_text | curated | Export advertising rule execution logs. Requires explicit user request/confirmation. |
| 重置 | text:重置 | button | safe_execute_allowed | click_visible_dom_text | curated | Clear current rule-log filters. |
| 日期范围 | column:执行时间 | date_filter | safe_execute_allowed | input_or_filter_placeholder_list | curated | Filter rule logs by execution date range. |
| 搜索内容 | placeholder:请输入搜索内容 | filter_input | safe_execute_allowed | input_or_filter_placeholder | curated | Search advertising rule execution logs. |
| 选择店铺 | placeholder:选择店铺 | filter_input | safe_execute_allowed | input_or_filter_placeholder | curated | Filter advertising rule execution logs by shop. |
| 成功 | 请选择 -> 成功 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 成功 from the 请选择 overlay on 广告规则执行日志. |
| 失败 | 请选择 -> 失败 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 失败 from the 请选择 overlay on 广告规则执行日志. |
| 请选择 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择 overlay on 广告规则执行日志. |
| 选择店铺 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 选择店铺 overlay on 广告规则执行日志. |
| 详情 | column:操作 | row_navigation | safe_execute_allowed | click_visible_dom_text | curated | Open detail for a visible advertising rule execution log row. |

## AI / 创作会话

- Route: `/ai/talk`
- Sources: auto
- Actions: 4

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 保存配置 | text:保存配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 创作会话; requires explicit confirmation before committing changes. |
| 用户菜单 | text:用户菜单 | button | safe_execute_allowed | click_visible_dom_text | auto | Open the current user/account menu. |
| 重置配置 | text:重置配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 创作会话; requires explicit confirmation before committing changes. |
| 首页 | text:首页 | navigation | safe_execute_allowed | navigate_href | auto | Navigate from 创作会话 to a related detail or analysis view. |

## BI / 售后单管理

- Route: `/bi/afterSalesOrder/index`
- Sources: auto, dialog, overlay
- Actions: 25

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 批量操作 | text:批量操作 | batch_action | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 售后单管理; requires explicit confirmation before committing changes. |
| 保存配置 | text:保存配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 售后单管理; requires explicit confirmation before committing changes. |
| 导入售后单 | text:导入售后单 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 售后单管理; requires explicit confirmation before committing changes. |
| 切换币种 | text:切换币种 | button | safe_execute_allowed | click_visible_dom_text | auto | Change the visible view setting on 售后单管理. |
| 搜索 | text:搜索 | button | safe_execute_allowed | click_visible_dom_text | auto | Apply or clear filters on 售后单管理. |
| 新增售后单 | text:新增售后单 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 售后单管理; requires explicit confirmation before committing changes. |
| 用户菜单 | text:用户菜单 | button | safe_execute_allowed | click_visible_dom_text | auto | Open the current user/account menu. |
| 重置 | text:重置 | button | safe_execute_allowed | click_visible_dom_text | auto | Apply or clear filters on 售后单管理. |
| 重置配置 | text:重置配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 售后单管理; requires explicit confirmation before committing changes. |
| 新增售后单取消 | 新增售后单 -> 取消 | dialog_button | safe_execute_allowed | click_trigger_selector_then_dialog_button_text | dialog | Use 取消 inside the 新增售后单 dialog/drawer on 售后单管理. |
| 新增售后单确定 | 新增售后单 -> 确定 | dialog_button | confirmation_required_write | click_trigger_selector_then_dialog_button_text | dialog | Use 确定 inside the 新增售后单 dialog/drawer on 售后单管理. |
| 新增售后单添加补发 | 新增售后单 -> 添加补发 | dialog_button | confirmation_required_write | click_trigger_selector_then_dialog_button_text | dialog | Use 添加补发 inside the 新增售后单 dialog/drawer on 售后单管理. |
| 新增售后单 |  | dialog_opener | safe_execute_allowed | click_trigger_selector | dialog | Open the 新增售后单 dialog/drawer on 售后单管理; do not submit changes without explicit confirmation. |
| 结束日期 | placeholder:结束日期 | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter 售后单管理 by 结束日期. |
| 开始日期 | placeholder:开始日期 | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter 售后单管理 by 开始日期. |
| 请输入订单号（双击批量搜索） | placeholder:请输入订单号（双击批量搜索） | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter 售后单管理 by 请输入订单号（双击批量搜索）. |
| 选择店铺 | placeholder:选择店铺 | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter 售后单管理 by 选择店铺. |
| 首页 | text:首页 | navigation | safe_execute_allowed | navigate_href | auto | Navigate from 售后单管理 to a related detail or analysis view. |
| 批量操作 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 批量操作 overlay on 售后单管理. |
| 请选择 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择 overlay on 售后单管理. |
| 选择店铺 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 选择店铺 overlay on 售后单管理. |
| 商品售后统计 |  | tab | safe_execute_allowed | click_visible_action_text | auto | Switch 售后单管理 to the 商品售后统计 tab/view. |
| 售后单 |  | tab | safe_execute_allowed | click_visible_action_text | auto | Switch 售后单管理 to the 售后单 tab/view. |
| 售后专项统计 |  | tab | safe_execute_allowed | click_visible_action_text | auto | Switch 售后单管理 to the 售后专项统计 tab/view. |
| 数据概览 |  | tab | safe_execute_allowed | click_visible_action_text | auto | Switch 售后单管理 to the 数据概览 tab/view. |

## BI / 推送监控

- Route: `/bi/monitor/pushFlowStats`
- Sources: auto
- Actions: 18

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 保存配置 | text:保存配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 推送监控; requires explicit confirmation before committing changes. |
| 刷新 Top10 | text:刷新 Top10 | button | safe_execute_allowed | click_visible_dom_text | auto | Change the visible view setting on 推送监控. |
| 刷新 | text:刷新 | button | safe_execute_allowed | click_visible_dom_text | auto | Change the visible view setting on 推送监控. |
| 用户菜单 | text:用户菜单 | button | safe_execute_allowed | click_visible_dom_text | auto | Open the current user/account menu. |
| 重置配置 | text:重置配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 推送监控; requires explicit confirmation before committing changes. |
| 首页 | text:首页 | navigation | safe_execute_allowed | navigate_href | auto | Navigate from 推送监控 to a related detail or analysis view. |
| 刷新同步详情 | text:刷新同步详情 | navigation | safe_execute_allowed | click_visible_dom_text | auto | Navigate from 推送监控 to a related detail or analysis view. |
| 待处理超时 |  | tab | safe_execute_allowed | click_visible_action_text | auto | Switch 推送监控 to the 待处理超时 tab/view. |
| 订单同步 |  | tab | safe_execute_allowed | click_visible_action_text | auto | Switch 推送监控 to the 订单同步 tab/view. |
| 拉单店铺 |  | tab | safe_execute_allowed | click_visible_action_text | auto | Switch 推送监控 to the 拉单店铺 tab/view. |
| 拉单租户 |  | tab | safe_execute_allowed | click_visible_action_text | auto | Switch 推送监控 to the 拉单租户 tab/view. |
| 平台推送 |  | tab | safe_execute_allowed | click_visible_action_text | auto | Switch 推送监控 to the 平台推送 tab/view. |
| 普通队列 |  | tab | safe_execute_allowed | click_visible_action_text | auto | Switch 推送监控 to the 普通队列 tab/view. |
| 入库店铺 |  | tab | safe_execute_allowed | click_visible_action_text | auto | Switch 推送监控 to the 入库店铺 tab/view. |
| 入库租户 |  | tab | safe_execute_allowed | click_visible_action_text | auto | Switch 推送监控 to the 入库租户 tab/view. |
| 同步点落后 |  | tab | safe_execute_allowed | click_visible_action_text | auto | Switch 推送监控 to the 同步点落后 tab/view. |
| 优先队列 |  | tab | safe_execute_allowed | click_visible_action_text | auto | Switch 推送监控 to the 优先队列 tab/view. |
| 执行中超时 |  | tab | safe_execute_allowed | click_visible_action_text | auto | Switch 推送监控 to the 执行中超时 tab/view. |

## BI / 售后单管理

- Route: `/bi/operationCenter/afterSaleOrder/index`
- Sources: auto, dialog, overlay
- Actions: 25

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 批量操作 | text:批量操作 | batch_action | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 售后单管理; requires explicit confirmation before committing changes. |
| 保存配置 | text:保存配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 售后单管理; requires explicit confirmation before committing changes. |
| 导入售后单 | text:导入售后单 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 售后单管理; requires explicit confirmation before committing changes. |
| 切换币种 | text:切换币种 | button | safe_execute_allowed | click_visible_dom_text | auto | Change the visible view setting on 售后单管理. |
| 搜索 | text:搜索 | button | safe_execute_allowed | click_visible_dom_text | auto | Apply or clear filters on 售后单管理. |
| 新增售后单 | text:新增售后单 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 售后单管理; requires explicit confirmation before committing changes. |
| 用户菜单 | text:用户菜单 | button | safe_execute_allowed | click_visible_dom_text | auto | Open the current user/account menu. |
| 重置 | text:重置 | button | safe_execute_allowed | click_visible_dom_text | auto | Apply or clear filters on 售后单管理. |
| 重置配置 | text:重置配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 售后单管理; requires explicit confirmation before committing changes. |
| 新增售后单取消 | 新增售后单 -> 取消 | dialog_button | safe_execute_allowed | click_trigger_selector_then_dialog_button_text | dialog | Use 取消 inside the 新增售后单 dialog/drawer on 售后单管理. |
| 新增售后单确定 | 新增售后单 -> 确定 | dialog_button | confirmation_required_write | click_trigger_selector_then_dialog_button_text | dialog | Use 确定 inside the 新增售后单 dialog/drawer on 售后单管理. |
| 新增售后单添加补发 | 新增售后单 -> 添加补发 | dialog_button | confirmation_required_write | click_trigger_selector_then_dialog_button_text | dialog | Use 添加补发 inside the 新增售后单 dialog/drawer on 售后单管理. |
| 新增售后单 |  | dialog_opener | safe_execute_allowed | click_trigger_selector | dialog | Open the 新增售后单 dialog/drawer on 售后单管理; do not submit changes without explicit confirmation. |
| 结束日期 | placeholder:结束日期 | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter 售后单管理 by 结束日期. |
| 开始日期 | placeholder:开始日期 | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter 售后单管理 by 开始日期. |
| 请输入订单号（双击批量搜索） | placeholder:请输入订单号（双击批量搜索） | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter 售后单管理 by 请输入订单号（双击批量搜索）. |
| 选择店铺 | placeholder:选择店铺 | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter 售后单管理 by 选择店铺. |
| 首页 | text:首页 | navigation | safe_execute_allowed | navigate_href | auto | Navigate from 售后单管理 to a related detail or analysis view. |
| 批量操作 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 批量操作 overlay on 售后单管理. |
| 请选择 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择 overlay on 售后单管理. |
| 选择店铺 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 选择店铺 overlay on 售后单管理. |
| 商品售后统计 |  | tab | safe_execute_allowed | click_visible_action_text | auto | Switch 售后单管理 to the 商品售后统计 tab/view. |
| 售后单 |  | tab | safe_execute_allowed | click_visible_action_text | auto | Switch 售后单管理 to the 售后单 tab/view. |
| 售后专项统计 |  | tab | safe_execute_allowed | click_visible_action_text | auto | Switch 售后单管理 to the 售后专项统计 tab/view. |
| 数据概览 |  | tab | safe_execute_allowed | click_visible_action_text | auto | Switch 售后单管理 to the 数据概览 tab/view. |

## BI / 售后单管理

- Route: `/bi/operationCenter/afterSalesOrder/index`
- Sources: auto, dialog, overlay
- Actions: 25

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 批量操作 | text:批量操作 | batch_action | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 售后单管理; requires explicit confirmation before committing changes. |
| 保存配置 | text:保存配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 售后单管理; requires explicit confirmation before committing changes. |
| 导入售后单 | text:导入售后单 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 售后单管理; requires explicit confirmation before committing changes. |
| 切换币种 | text:切换币种 | button | safe_execute_allowed | click_visible_dom_text | auto | Change the visible view setting on 售后单管理. |
| 搜索 | text:搜索 | button | safe_execute_allowed | click_visible_dom_text | auto | Apply or clear filters on 售后单管理. |
| 新增售后单 | text:新增售后单 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 售后单管理; requires explicit confirmation before committing changes. |
| 用户菜单 | text:用户菜单 | button | safe_execute_allowed | click_visible_dom_text | auto | Open the current user/account menu. |
| 重置 | text:重置 | button | safe_execute_allowed | click_visible_dom_text | auto | Apply or clear filters on 售后单管理. |
| 重置配置 | text:重置配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 售后单管理; requires explicit confirmation before committing changes. |
| 新增售后单取消 | 新增售后单 -> 取消 | dialog_button | safe_execute_allowed | click_trigger_selector_then_dialog_button_text | dialog | Use 取消 inside the 新增售后单 dialog/drawer on 售后单管理. |
| 新增售后单确定 | 新增售后单 -> 确定 | dialog_button | confirmation_required_write | click_trigger_selector_then_dialog_button_text | dialog | Use 确定 inside the 新增售后单 dialog/drawer on 售后单管理. |
| 新增售后单添加补发 | 新增售后单 -> 添加补发 | dialog_button | confirmation_required_write | click_trigger_selector_then_dialog_button_text | dialog | Use 添加补发 inside the 新增售后单 dialog/drawer on 售后单管理. |
| 新增售后单 |  | dialog_opener | safe_execute_allowed | click_trigger_selector | dialog | Open the 新增售后单 dialog/drawer on 售后单管理; do not submit changes without explicit confirmation. |
| 结束日期 | placeholder:结束日期 | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter 售后单管理 by 结束日期. |
| 开始日期 | placeholder:开始日期 | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter 售后单管理 by 开始日期. |
| 请输入订单号（双击批量搜索） | placeholder:请输入订单号（双击批量搜索） | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter 售后单管理 by 请输入订单号（双击批量搜索）. |
| 选择店铺 | placeholder:选择店铺 | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter 售后单管理 by 选择店铺. |
| 首页 | text:首页 | navigation | safe_execute_allowed | navigate_href | auto | Navigate from 售后单管理 to a related detail or analysis view. |
| 批量操作 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 批量操作 overlay on 售后单管理. |
| 请选择 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择 overlay on 售后单管理. |
| 选择店铺 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 选择店铺 overlay on 售后单管理. |
| 商品售后统计 |  | tab | safe_execute_allowed | click_visible_action_text | auto | Switch 售后单管理 to the 商品售后统计 tab/view. |
| 售后单 |  | tab | safe_execute_allowed | click_visible_action_text | auto | Switch 售后单管理 to the 售后单 tab/view. |
| 售后专项统计 |  | tab | safe_execute_allowed | click_visible_action_text | auto | Switch 售后单管理 to the 售后专项统计 tab/view. |
| 数据概览 |  | tab | safe_execute_allowed | click_visible_action_text | auto | Switch 售后单管理 to the 数据概览 tab/view. |

## BI / 店铺利润分析详情

- Route: `/bi/profit/detail`
- Sources: auto
- Actions: 12

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 保存配置 | text:保存配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 店铺利润分析详情; requires explicit confirmation before committing changes. |
| 切换到汇总视图 | text:切换到汇总视图 | button | safe_execute_allowed | click_visible_dom_text | auto | Change the visible view setting on 店铺利润分析详情. |
| 用户菜单 | text:用户菜单 | button | safe_execute_allowed | click_visible_dom_text | auto | Open the current user/account menu. |
| 重置 | text:重置 | button | safe_execute_allowed | click_visible_dom_text | auto | Apply or clear filters on 店铺利润分析详情. |
| 重置配置 | text:重置配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 店铺利润分析详情; requires explicit confirmation before committing changes. |
| 结束日期 | placeholder:结束日期 | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter 店铺利润分析详情 by 结束日期. |
| 开始日期 | placeholder:开始日期 | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter 店铺利润分析详情 by 开始日期. |
| 首页 | text:首页 | navigation | safe_execute_allowed | navigate_href | auto | Navigate from 店铺利润分析详情 to a related detail or analysis view. |
| 今天 |  | tab | safe_execute_allowed | click_visible_action_text | auto | Switch 店铺利润分析详情 to the 今天 tab/view. |
| 近30天 |  | tab | safe_execute_allowed | click_visible_action_text | auto | Switch 店铺利润分析详情 to the 近30天 tab/view. |
| 近7天 |  | tab | safe_execute_allowed | click_visible_action_text | auto | Switch 店铺利润分析详情 to the 近7天 tab/view. |
| 昨天 |  | tab | safe_execute_allowed | click_visible_action_text | auto | Switch 店铺利润分析详情 to the 昨天 tab/view. |

## BI / 商品复购分析报告详情

- Route: `/user-analyze/detail`
- Sources: auto
- Actions: 6

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 保存配置 | text:保存配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 商品复购分析报告详情; requires explicit confirmation before committing changes. |
| 用户菜单 | text:用户菜单 | button | safe_execute_allowed | click_visible_dom_text | auto | Open the current user/account menu. |
| 重置配置 | text:重置配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 商品复购分析报告详情; requires explicit confirmation before committing changes. |
| 结束日期 | placeholder:结束日期 | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter 商品复购分析报告详情 by 结束日期. |
| 开始日期 | placeholder:开始日期 | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter 商品复购分析报告详情 by 开始日期. |
| 首页 | text:首页 | navigation | safe_execute_allowed | navigate_href | auto | Navigate from 商品复购分析报告详情 to a related detail or analysis view. |

## CRM / 合作单详情

- Route: `/crm/coopera-detail`
- Sources: auto
- Actions: 4

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 保存配置 | text:保存配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 合作单详情; requires explicit confirmation before committing changes. |
| 用户菜单 | text:用户菜单 | button | safe_execute_allowed | click_visible_dom_text | auto | Open the current user/account menu. |
| 重置配置 | text:重置配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 合作单详情; requires explicit confirmation before committing changes. |
| 首页 | text:首页 | navigation | safe_execute_allowed | navigate_href | auto | Navigate from 合作单详情 to a related detail or analysis view. |

## CRM / 合作单详情

- Route: `/crm/cooperation-detail-simple`
- Sources: auto
- Actions: 8

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 保存配置 | text:保存配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 合作单详情; requires explicit confirmation before committing changes. |
| 用户菜单 | text:用户菜单 | button | safe_execute_allowed | click_visible_dom_text | auto | Open the current user/account menu. |
| 重置配置 | text:重置配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 合作单详情; requires explicit confirmation before committing changes. |
| 首页 | text:首页 | navigation | safe_execute_allowed | navigate_href | auto | Navigate from 合作单详情 to a related detail or analysis view. |
| 订单列表 |  | tab | safe_execute_allowed | click_visible_action_text | auto | Switch 合作单详情 to the 订单列表 tab/view. |
| 视频链接 |  | tab | safe_execute_allowed | click_visible_action_text | auto | Switch 合作单详情 to the 视频链接 tab/view. |
| 销售数据 |  | tab | safe_execute_allowed | click_visible_action_text | auto | Switch 合作单详情 to the 销售数据 tab/view. |
| 直播链接 |  | tab | safe_execute_allowed | click_visible_action_text | auto | Switch 合作单详情 to the 直播链接 tab/view. |

## CRM / 合作单详情

- Route: `/crm/cooperation-detail`
- Sources: auto
- Actions: 8

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 保存配置 | text:保存配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 合作单详情; requires explicit confirmation before committing changes. |
| 用户菜单 | text:用户菜单 | button | safe_execute_allowed | click_visible_dom_text | auto | Open the current user/account menu. |
| 重置配置 | text:重置配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 合作单详情; requires explicit confirmation before committing changes. |
| 首页 | text:首页 | navigation | safe_execute_allowed | navigate_href | auto | Navigate from 合作单详情 to a related detail or analysis view. |
| 订单列表 |  | tab | safe_execute_allowed | click_visible_action_text | auto | Switch 合作单详情 to the 订单列表 tab/view. |
| 视频链接 |  | tab | safe_execute_allowed | click_visible_action_text | auto | Switch 合作单详情 to the 视频链接 tab/view. |
| 销售数据 |  | tab | safe_execute_allowed | click_visible_action_text | auto | Switch 合作单详情 to the 销售数据 tab/view. |
| 直播链接 |  | tab | safe_execute_allowed | click_visible_action_text | auto | Switch 合作单详情 to the 直播链接 tab/view. |

## CRM / 收藏夹详情

- Route: `/crm/favorite/detail`
- Sources: auto, overlay
- Actions: 15

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 批量操作 | text:批量操作 | batch_action | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 收藏夹详情; requires explicit confirmation before committing changes. |
| 保存配置 | text:保存配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 收藏夹详情; requires explicit confirmation before committing changes. |
| 去达人广场添加 | text:去达人广场添加 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 收藏夹详情; requires explicit confirmation before committing changes. |
| 群发邮件 | text:群发邮件 | button | manual_review | click_visible_dom_text | auto | Observed 群发邮件 control on 收藏夹详情; exact behavior has not been clicked yet. |
| 搜索 | text:搜索 | button | safe_execute_allowed | click_visible_dom_text | auto | Apply or clear filters on 收藏夹详情. |
| 用户菜单 | text:用户菜单 | button | safe_execute_allowed | click_visible_dom_text | auto | Open the current user/account menu. |
| 重置 | text:重置 | button | safe_execute_allowed | click_visible_dom_text | auto | Apply or clear filters on 收藏夹详情. |
| 重置配置 | text:重置配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 收藏夹详情; requires explicit confirmation before committing changes. |
| 邀约次数 | text:邀约次数 | filter_dropdown | safe_execute_allowed | click_visible_dom_text | auto | Filter 收藏夹详情 by 邀约次数. |
| 请输入昵称或达人ID | placeholder:请输入昵称或达人ID | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter 收藏夹详情 by 请输入昵称或达人ID. |
| 邀约次数 | placeholder:邀约次数 | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter 收藏夹详情 by 邀约次数. |
| 首页 | text:首页 | navigation | safe_execute_allowed | navigate_href | auto | Navigate from 收藏夹详情 to a related detail or analysis view. |
| 批量操作 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 批量操作 overlay on 收藏夹详情. |
| 请选择 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择 overlay on 收藏夹详情. |
| 邀约次数 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 邀约次数 overlay on 收藏夹详情. |

## CRM / 黑名单

- Route: `/crm/matser/management/blacklist`
- Sources: curated, overlay
- Actions: 7

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 批量恢复 | text:批量恢复 | button | confirmation_required_write | click_visible_dom_text | curated | Restore selected creators from blacklist. Requires selected rows and explicit confirmation. |
| 搜索 | text:搜索 | button | safe_execute_allowed | click_visible_dom_text | curated | Apply current blacklist filters. |
| 重置 | text:重置 | button | safe_execute_allowed | click_visible_dom_text | curated | Clear current blacklist filters. |
| 达人标签 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 达人标签 overlay on 黑名单. |
| 品类 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 品类 overlay on 黑名单. |
| 请选择 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择 overlay on 黑名单. |
| 全部商务 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 全部商务 overlay on 黑名单. |

## CRM / 重点关注

- Route: `/crm/matser/management/focus`
- Sources: curated, overlay
- Actions: 8

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 搜索 | text:搜索 | button | safe_execute_allowed | click_visible_dom_text | curated | Apply current focus-page filters. |
| 重置 | text:重置 | button | safe_execute_allowed | click_visible_dom_text | curated | Clear current focus-page filters. |
| 转移达人 | text:转移达人 | button | confirmation_required_write | click_visible_dom_text | curated | Transfer selected creators. Requires selected rows and explicit confirmation. |
| 品类 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 品类 overlay on 重点关注. |
| 请选择 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择 overlay on 重点关注. |
| 全部商务 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 全部商务 overlay on 重点关注. |
| 选择标签 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 选择标签 overlay on 重点关注. |
| 状态 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 状态 overlay on 重点关注. |

## CRM / 达人公海

- Route: `/crm/matser/management/highSeas`
- Sources: curated, overlay
- Actions: 31

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 批量操作 | text:批量操作 | button_menu | confirmation_required_write | click_visible_dom_text | curated | Open batch operation menu for selected creators. Treat concrete batch action as unknown until the menu is captured. |
| 分配达人 | text:分配达人 | button | confirmation_required_write | click_visible_dom_text | curated | Assign selected creators to a business owner. Requires selected rows and explicit user confirmation. |
| 认领达人 | text:认领达人 | button | confirmation_required_write | click_visible_dom_text | curated | Claim selected creators into the current user's task/follow-up pool. Requires explicit user confirmation. |
| 搜索 | text:搜索 | button | safe_execute_allowed | click_visible_dom_text | curated | Apply current filters and refresh the creator list. |
| 重置 | text:重置 | button | safe_execute_allowed | click_visible_dom_text | curated | Clear high-seas filters and return to the default list. |
| 地区 | uia:地区 | filter_dropdown | safe_execute_allowed | uia_locator | curated | Filter creators by region. |
| 粉丝数 | uia:粉丝数 | filter_dropdown | safe_execute_allowed | uia_locator | curated | Filter creators by follower-count range. |
| 全部商务 | placeholder:全部商务 | filter_dropdown | safe_execute_allowed | input_or_filter_placeholder | curated | Filter creators by business owner/follow-up owner. |
| 性别分布 | uia:性别分布 | filter_dropdown | safe_execute_allowed | uia_locator | curated | Filter creators by audience gender distribution. |
| 达人ID | placeholder:请输入达人ID(双击批量搜索) | filter_input | safe_execute_allowed | input_or_filter_placeholder | curated | Search one or multiple creator IDs. The placeholder says double-click for batch search. |
| 年龄分布 | placeholder:年龄分布 | filter_input | safe_execute_allowed | input_or_filter_placeholder | curated | Filter creators by audience age distribution. |
| 品类 | placeholder:品类 | filter_input | safe_execute_allowed | input_or_filter_placeholder | curated | Filter creators by product/category fit. |
| 选择标签 | placeholder:选择标签 | filter_input | safe_execute_allowed | input_or_filter_placeholder | curated | Filter creators by tag. |
| 选择店铺 | placeholder:选择店铺 | filter_input | safe_execute_allowed | input_or_filter_placeholder | curated | Filter creators by shop. |
| 批量达人昵称 | 批量操作 -> 达人昵称 | overlay_item | confirmation_required_write | click_trigger_selector_then_overlay_item_text | overlay | Choose 达人昵称 from the 批量操作 overlay on 达人公海. |
| 批量达人ID | 批量操作 -> 达人ID | overlay_item | confirmation_required_write | click_trigger_selector_then_overlay_item_text | overlay | Choose 达人ID from the 批量操作 overlay on 达人公海. |
| 批量删除 | 批量操作 -> 批量删除 | overlay_item | confirmation_required_write | click_trigger_selector_then_overlay_item_text | overlay | Choose 批量删除 from the 批量操作 overlay on 达人公海. |
| 批量删除 | 请选择 -> 批量删除 | overlay_item | confirmation_required_write | click_trigger_selector_then_overlay_item_text | overlay | Choose 批量删除 from the 请选择 overlay on 达人公海. |
| 批量信息更新 | 批量操作 -> 信息更新 | overlay_item | confirmation_required_write | click_trigger_selector_then_overlay_item_text | overlay | Choose 信息更新 from the 批量操作 overlay on 达人公海. |
| 年龄分布 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 年龄分布 overlay on 达人公海. |
| 批量操作 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 批量操作 overlay on 达人公海. |
| 品类 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 品类 overlay on 达人公海. |
| 请选择 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择 overlay on 达人公海. |
| 全部商务 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 全部商务 overlay on 达人公海. |
| 选择标签 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 选择标签 overlay on 达人公海. |
| 选择店铺 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 选择店铺 overlay on 达人公海. |
| 合作中 |  | status_tab | safe_execute_allowed | click_visible_action_text | curated | Show creators currently cooperating. |
| 全部 |  | status_tab | safe_execute_allowed | click_visible_action_text | curated | Show all creators in the high-seas list. |
| 已出单 |  | status_tab | safe_execute_allowed | click_visible_action_text | curated | Show creators that already generated orders. |
| 已触达 |  | status_tab | safe_execute_allowed | click_visible_action_text | curated | Show creators already reached/contacted. |
| 已申样 |  | status_tab | safe_execute_allowed | click_visible_action_text | curated | Show creators already in sample request status. |

## CRM / 我的达人

- Route: `/crm/matser/management/myMaster`
- Sources: curated, overlay
- Actions: 5

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 批量操作 | text:批量操作 | button_menu | confirmation_required_write | click_visible_dom_text | curated | Open batch operation menu. Concrete menu items still need capture after opening the menu. |
| 搜索 | text:搜索 | button | safe_execute_allowed | click_visible_dom_text | curated | Apply current my-master filters. |
| 添加达人 | text:添加达人 | button | confirmation_required_write | click_visible_dom_text | curated | Open add-creator flow. Requires explicit confirmation before submitting any data. |
| 重置 | text:重置 | button | safe_execute_allowed | click_visible_dom_text | curated | Clear current my-master filters. |
| 批量操作 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 批量操作 overlay on 我的达人. |

## CRM / 店铺详情

- Route: `/crm/shop-detail`
- Sources: auto, overlay
- Actions: 7

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 保存配置 | text:保存配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 店铺详情; requires explicit confirmation before committing changes. |
| 用户菜单 | text:用户菜单 | button | safe_execute_allowed | click_visible_dom_text | auto | Open the current user/account menu. |
| 重置配置 | text:重置配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 店铺详情; requires explicit confirmation before committing changes. |
| 首页 | text:首页 | navigation | safe_execute_allowed | navigate_href | auto | Navigate from 店铺详情 to a related detail or analysis view. |
| 请选择 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择 overlay on 店铺详情. |
| 店铺商品 |  | tab | safe_execute_allowed | click_visible_action_text | auto | Switch 店铺详情 to the 店铺商品 tab/view. |
| 关联达人 |  | tab | safe_execute_allowed | click_visible_action_text | auto | Switch 店铺详情 to the 关联达人 tab/view. |

## CRM / 数据概览

- Route: `/dataView/data-overview`
- Sources: curated, overlay
- Actions: 6

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 搜索 | text:搜索 | button | safe_execute_allowed | click_visible_dom_text | curated | Apply current data-overview filters. |
| 重置 | text:重置 | button | safe_execute_allowed | click_visible_dom_text | curated | Clear current data-overview filters. |
| 请选择 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择 overlay on 数据概览. |
| 全部商务 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 全部商务 overlay on 数据概览. |
| 搜索商品名称或链接ID |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 搜索商品名称或链接ID overlay on 数据概览. |
| 选择店铺 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 选择店铺 overlay on 数据概览. |

## ERP / 流程定义

- Route: `/bpm/manager/definition`
- Sources: auto
- Actions: 4

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 保存配置 | text:保存配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 流程定义; requires explicit confirmation before committing changes. |
| 用户菜单 | text:用户菜单 | button | safe_execute_allowed | click_visible_dom_text | auto | Open the current user/account menu. |
| 重置配置 | text:重置配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 流程定义; requires explicit confirmation before committing changes. |
| 首页 | text:首页 | navigation | safe_execute_allowed | navigate_href | auto | Navigate from 流程定义 to a related detail or analysis view. |

## ERP / 发起 OA 请假

- Route: `/bpm/oa/leave/create`
- Sources: auto, overlay
- Actions: 9

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 保存配置 | text:保存配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 发起 OA 请假; requires explicit confirmation before committing changes. |
| 提 交 | text:提 交 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 发起 OA 请假; requires explicit confirmation before committing changes. |
| 用户菜单 | text:用户菜单 | button | safe_execute_allowed | click_visible_dom_text | auto | Open the current user/account menu. |
| 重置配置 | text:重置配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 发起 OA 请假; requires explicit confirmation before committing changes. |
| 请输入原因 | placeholder:请输入原因 | form_input | manual_review | input_or_filter_placeholder | auto | Fill or choose the 请输入原因 field on 发起 OA 请假; submitting the form still requires explicit confirmation. |
| 选择结束时间 | placeholder:选择结束时间 | form_input | manual_review | input_or_filter_placeholder | auto | Fill or choose the 选择结束时间 field on 发起 OA 请假; submitting the form still requires explicit confirmation. |
| 选择开始时间 | placeholder:选择开始时间 | form_input | manual_review | input_or_filter_placeholder | auto | Fill or choose the 选择开始时间 field on 发起 OA 请假; submitting the form still requires explicit confirmation. |
| 首页 | text:首页 | navigation | safe_execute_allowed | navigate_href | auto | Navigate from 发起 OA 请假 to a related detail or analysis view. |
| 请选择 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择 overlay on 发起 OA 请假. |

## ERP / 查看 OA 请假

- Route: `/bpm/oa/leave/detail`
- Sources: auto
- Actions: 4

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 保存配置 | text:保存配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 查看 OA 请假; requires explicit confirmation before committing changes. |
| 用户菜单 | text:用户菜单 | button | safe_execute_allowed | click_visible_dom_text | auto | Open the current user/account menu. |
| 重置配置 | text:重置配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 查看 OA 请假; requires explicit confirmation before committing changes. |
| 首页 | text:首页 | navigation | safe_execute_allowed | navigate_href | auto | Navigate from 查看 OA 请假 to a related detail or analysis view. |

## ERP / 发起流程

- Route: `/bpm/process-instance/create`
- Sources: auto
- Actions: 4

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 保存配置 | text:保存配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 发起流程; requires explicit confirmation before committing changes. |
| 用户菜单 | text:用户菜单 | button | safe_execute_allowed | click_visible_dom_text | auto | Open the current user/account menu. |
| 重置配置 | text:重置配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 发起流程; requires explicit confirmation before committing changes. |
| 首页 | text:首页 | navigation | safe_execute_allowed | navigate_href | auto | Navigate from 发起流程 to a related detail or analysis view. |

## ERP / 流程详情

- Route: `/bpm/process-instance/detail`
- Sources: auto
- Actions: 4

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 保存配置 | text:保存配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 流程详情; requires explicit confirmation before committing changes. |
| 用户菜单 | text:用户菜单 | button | safe_execute_allowed | click_visible_dom_text | auto | Open the current user/account menu. |
| 重置配置 | text:重置配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 流程详情; requires explicit confirmation before committing changes. |
| 首页 | text:首页 | navigation | safe_execute_allowed | navigate_href | auto | Navigate from 流程详情 to a related detail or analysis view. |

## ERP / 黑名单管理

- Route: `/erp/blacklist`
- Sources: auto, dialog
- Actions: 13

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 批量删除 | text:批量删除 | batch_action | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 黑名单管理; requires explicit confirmation before committing changes. |
| 保存配置 | text:保存配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 黑名单管理; requires explicit confirmation before committing changes. |
| 新增 | text:新增 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 黑名单管理; requires explicit confirmation before committing changes. |
| 用户菜单 | text:用户菜单 | button | safe_execute_allowed | click_visible_dom_text | auto | Open the current user/account menu. |
| 重置 | text:重置 | button | safe_execute_allowed | click_visible_dom_text | auto | Apply or clear filters on 黑名单管理. |
| 重置配置 | text:重置配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 黑名单管理; requires explicit confirmation before committing changes. |
| 自动加黑 | text:自动加黑 | button | manual_review | click_visible_dom_text | auto | Observed 自动加黑 control on 黑名单管理; exact behavior has not been clicked yet. |
| 新增关闭 | 新增 -> 关闭 | dialog_button | safe_execute_allowed | click_trigger_selector_then_dialog_button_text | dialog | Use 关闭 inside the 新增 dialog/drawer on 黑名单管理. |
| 新增取消 | 新增 -> 取消 | dialog_button | safe_execute_allowed | click_trigger_selector_then_dialog_button_text | dialog | Use 取消 inside the 新增 dialog/drawer on 黑名单管理. |
| 新增确定 | 新增 -> 确定 | dialog_button | confirmation_required_write | click_trigger_selector_then_dialog_button_text | dialog | Use 确定 inside the 新增 dialog/drawer on 黑名单管理. |
| 新增 |  | dialog_opener | safe_execute_allowed | click_trigger_selector | dialog | Open the 新增 dialog/drawer on 黑名单管理; do not submit changes without explicit confirmation. |
| 请输入买家地址 | placeholder:请输入买家地址 | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter 黑名单管理 by 请输入买家地址. |
| 首页 | text:首页 | navigation | safe_execute_allowed | navigate_href | auto | Navigate from 黑名单管理 to a related detail or analysis view. |

## ERP / 调度日志

- Route: `/job/log`
- Sources: auto, overlay
- Actions: 14

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 保存配置 | text:保存配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 调度日志; requires explicit confirmation before committing changes. |
| 搜索 | text:搜索 | button | safe_execute_allowed | click_visible_dom_text | auto | Apply or clear filters on 调度日志. |
| 用户菜单 | text:用户菜单 | button | safe_execute_allowed | click_visible_dom_text | auto | Open the current user/account menu. |
| 重置 | text:重置 | button | safe_execute_allowed | click_visible_dom_text | auto | Apply or clear filters on 调度日志. |
| 重置配置 | text:重置配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 调度日志; requires explicit confirmation before committing changes. |
| 请选择任务状态 | text:请选择任务状态 | filter_dropdown | safe_execute_allowed | click_visible_dom_text | auto | Filter 调度日志 by 请选择任务状态. |
| 请输入处理器的名字 | placeholder:请输入处理器的名字 | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter 调度日志 by 请输入处理器的名字. |
| 请选择任务状态 | placeholder:请选择任务状态 | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter 调度日志 by 请选择任务状态. |
| 选择结束执行时间 | placeholder:选择结束执行时间 | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter 调度日志 by 选择结束执行时间. |
| 选择开始执行时间 | placeholder:选择开始执行时间 | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter 调度日志 by 选择开始执行时间. |
| 首页 | text:首页 | navigation | safe_execute_allowed | navigate_href | auto | Navigate from 调度日志 to a related detail or analysis view. |
| 成功 | 请选择任务状态 -> 成功 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 成功 from the 请选择任务状态 overlay on 调度日志. |
| 失败 | 请选择任务状态 -> 失败 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 失败 from the 请选择任务状态 overlay on 调度日志. |
| 请选择任务状态 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择任务状态 overlay on 调度日志. |

## ERP / 预警消息

- Route: `/monitor/message_list`
- Sources: auto, overlay
- Actions: 20

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 保存配置 | text:保存配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 预警消息; requires explicit confirmation before committing changes. |
| 标记未处理 | text:标记未处理 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 预警消息; requires explicit confirmation before committing changes. |
| 标记已处理 | text:标记已处理 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 预警消息; requires explicit confirmation before committing changes. |
| 用户菜单 | text:用户菜单 | button | safe_execute_allowed | click_visible_dom_text | auto | Open the current user/account menu. |
| 重置 | text:重置 | button | safe_execute_allowed | click_visible_dom_text | auto | Apply or clear filters on 预警消息. |
| 重置配置 | text:重置配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 预警消息; requires explicit confirmation before committing changes. |
| 结束日期 | placeholder:结束日期 | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter 预警消息 by 结束日期. |
| 开始日期 | placeholder:开始日期 | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter 预警消息 by 开始日期. |
| 请输入规则名称 | placeholder:请输入规则名称 | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter 预警消息 by 请输入规则名称. |
| 选择店铺 | placeholder:选择店铺 | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter 预警消息 by 选择店铺. |
| 店铺健康 | text:店铺健康 | navigation | safe_execute_allowed | navigate_href | auto | Navigate from 预警消息 to a related detail or analysis view. |
| 首页 | text:首页 | navigation | safe_execute_allowed | navigate_href | auto | Navigate from 预警消息 to a related detail or analysis view. |
| 售价监控 | text:售价监控 | navigation | safe_execute_allowed | navigate_href | auto | Navigate from 预警消息 to a related detail or analysis view. |
| 物流监控 | text:物流监控 | navigation | safe_execute_allowed | navigate_href | auto | Navigate from 预警消息 to a related detail or analysis view. |
| 预警规则 | text:预警规则 | navigation | safe_execute_allowed | navigate_href | auto | Navigate from 预警消息 to a related detail or analysis view. |
| 预警消息 | text:预警消息 | navigation | safe_execute_allowed | navigate_href | auto | Navigate from 预警消息 to a related detail or analysis view. |
| 按店铺 | 请选择 -> 按店铺 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 按店铺 from the 请选择 overlay on 预警消息. |
| 按人员 | 请选择 -> 按人员 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 按人员 from the 请选择 overlay on 预警消息. |
| 请选择 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择 overlay on 预警消息. |
| 选择店铺 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 选择店铺 overlay on 预警消息. |

## ERP / SKU最低售价配置

- Route: `/order/sku-min-price`
- Sources: auto, dialog, overlay
- Actions: 20

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 批量删除 | text:批量删除 | batch_action | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on SKU最低售价配置; requires explicit confirmation before committing changes. |
| 保存配置 | text:保存配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on SKU最低售价配置; requires explicit confirmation before committing changes. |
| 导入导出 | text:导入导出 | button | confirmation_required_export | click_visible_dom_text | auto | Export or download data from SKU最低售价配置; requires an explicit user request. |
| 搜索 | text:搜索 | button | safe_execute_allowed | click_visible_dom_text | auto | Apply or clear filters on SKU最低售价配置. |
| 新增 | text:新增 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on SKU最低售价配置; requires explicit confirmation before committing changes. |
| 用户菜单 | text:用户菜单 | button | safe_execute_allowed | click_visible_dom_text | auto | Open the current user/account menu. |
| 重置 | text:重置 | button | safe_execute_allowed | click_visible_dom_text | auto | Apply or clear filters on SKU最低售价配置. |
| 重置配置 | text:重置配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on SKU最低售价配置; requires explicit confirmation before committing changes. |
| 新增关闭 | 新增 -> 关闭 | dialog_button | safe_execute_allowed | click_trigger_selector_then_dialog_button_text | dialog | Use 关闭 inside the 新增 dialog/drawer on SKU最低售价配置. |
| 新增取消 | 新增 -> 取消 | dialog_button | safe_execute_allowed | click_trigger_selector_then_dialog_button_text | dialog | Use 取消 inside the 新增 dialog/drawer on SKU最低售价配置. |
| 新增确定 | 新增 -> 确定 | dialog_button | confirmation_required_write | click_trigger_selector_then_dialog_button_text | dialog | Use 确定 inside the 新增 dialog/drawer on SKU最低售价配置. |
| 新增选择 | 新增 -> 选择 | dialog_button | manual_review | click_trigger_selector_then_dialog_button_text | dialog | Use 选择 inside the 新增 dialog/drawer on SKU最低售价配置. |
| 新增 |  | dialog_opener | safe_execute_allowed | click_trigger_selector | dialog | Open the 新增 dialog/drawer on SKU最低售价配置; do not submit changes without explicit confirmation. |
| 请输入商品SKU | placeholder:请输入商品SKU | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter SKU最低售价配置 by 请输入商品SKU. |
| 选择店铺 | placeholder:选择店铺 | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter SKU最低售价配置 by 选择店铺. |
| 首页 | text:首页 | navigation | safe_execute_allowed | navigate_href | auto | Navigate from SKU最低售价配置 to a related detail or analysis view. |
| 导出最低售价 | 导入导出 -> 导出最低售价 | overlay_item | confirmation_required_export | click_trigger_selector_then_overlay_item_text | overlay | Choose 导出最低售价 from the 导入导出 overlay on SKU最低售价配置. |
| 导入导出 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 导入导出 overlay on SKU最低售价配置. |
| 请选择 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择 overlay on SKU最低售价配置. |
| 选择店铺 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 选择店铺 overlay on SKU最低售价配置. |

## ERP / 商品评论详情

- Route: `/product-data/detail`
- Sources: auto, overlay
- Actions: 16

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 保存配置 | text:保存配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 商品评论详情; requires explicit confirmation before committing changes. |
| 同步评论 | text:同步评论 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 商品评论详情; requires explicit confirmation before committing changes. |
| 用户菜单 | text:用户菜单 | button | safe_execute_allowed | click_visible_dom_text | auto | Open the current user/account menu. |
| 重置 | text:重置 | button | safe_execute_allowed | click_visible_dom_text | auto | Apply or clear filters on 商品评论详情. |
| 重置配置 | text:重置配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 商品评论详情; requires explicit confirmation before committing changes. |
| 结束日期 | placeholder:结束日期 | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter 商品评论详情 by 结束日期. |
| 开始日期 | placeholder:开始日期 | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter 商品评论详情 by 开始日期. |
| 请输入平台订单号 | placeholder:请输入平台订单号 | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter 商品评论详情 by 请输入平台订单号. |
| 首页 | text:首页 | navigation | safe_execute_allowed | navigate_href | auto | Navigate from 商品评论详情 to a related detail or analysis view. |
| 未处理 | 请选择 -> 未处理 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 未处理 from the 请选择 overlay on 商品评论详情. |
| 已处理 | 请选择 -> 已处理 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 已处理 from the 请选择 overlay on 商品评论详情. |
| 请选择 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择 overlay on 商品评论详情. |
| 今天 |  | tab | safe_execute_allowed | click_visible_action_text | auto | Switch 商品评论详情 to the 今天 tab/view. |
| 近30天 |  | tab | safe_execute_allowed | click_visible_action_text | auto | Switch 商品评论详情 to the 近30天 tab/view. |
| 近7天 |  | tab | safe_execute_allowed | click_visible_action_text | auto | Switch 商品评论详情 to the 近7天 tab/view. |
| 昨天 |  | tab | safe_execute_allowed | click_visible_action_text | auto | Switch 商品评论详情 to the 昨天 tab/view. |

## ERP / 商品表现分析

- Route: `/product-data/performance-detail`
- Sources: auto
- Actions: 4

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 保存配置 | text:保存配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 商品表现分析; requires explicit confirmation before committing changes. |
| 用户菜单 | text:用户菜单 | button | safe_execute_allowed | click_visible_dom_text | auto | Open the current user/account menu. |
| 重置配置 | text:重置配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 商品表现分析; requires explicit confirmation before committing changes. |
| 首页 | text:首页 | navigation | safe_execute_allowed | navigate_href | auto | Navigate from 商品表现分析 to a related detail or analysis view. |

## ERP / 进销存详情

- Route: `/product-sku/InventoryReport_detail`
- Sources: auto, overlay
- Actions: 12

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 保存配置 | text:保存配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 进销存详情; requires explicit confirmation before committing changes. |
| 搜索 | text:搜索 | button | safe_execute_allowed | click_visible_dom_text | auto | Apply or clear filters on 进销存详情. |
| 用户菜单 | text:用户菜单 | button | safe_execute_allowed | click_visible_dom_text | auto | Open the current user/account menu. |
| 重置 | text:重置 | button | safe_execute_allowed | click_visible_dom_text | auto | Apply or clear filters on 进销存详情. |
| 重置配置 | text:重置配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 进销存详情; requires explicit confirmation before committing changes. |
| 结束日期 | placeholder:结束日期 | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter 进销存详情 by 结束日期. |
| 开始日期 | placeholder:开始日期 | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter 进销存详情 by 开始日期. |
| 首页 | text:首页 | navigation | safe_execute_allowed | navigate_href | auto | Navigate from 进销存详情 to a related detail or analysis view. |
| 请选择 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择 overlay on 进销存详情. |
| 近30天 |  | tab | safe_execute_allowed | click_visible_action_text | auto | Switch 进销存详情 to the 近30天 tab/view. |
| 近7天 |  | tab | safe_execute_allowed | click_visible_action_text | auto | Switch 进销存详情 to the 近7天 tab/view. |
| 昨天 |  | tab | safe_execute_allowed | click_visible_action_text | auto | Switch 进销存详情 to the 昨天 tab/view. |

## ERP / 业绩利润报表

- Route: `/report-center/detail/performance`
- Sources: auto, overlay
- Actions: 13

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 保存配置 | text:保存配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 业绩利润报表; requires explicit confirmation before committing changes. |
| 导出报表 | text:导出报表 | button | confirmation_required_export | click_visible_dom_text | auto | Export or download data from 业绩利润报表; requires an explicit user request. |
| 用户菜单 | text:用户菜单 | button | safe_execute_allowed | click_visible_dom_text | auto | Open the current user/account menu. |
| 重置 | text:重置 | button | safe_execute_allowed | click_visible_dom_text | auto | Apply or clear filters on 业绩利润报表. |
| 重置配置 | text:重置配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 业绩利润报表; requires explicit confirmation before committing changes. |
| 请选择运营人员 | text:请选择运营人员 | filter_dropdown | safe_execute_allowed | click_visible_dom_text | auto | Filter 业绩利润报表 by 请选择运营人员. |
| 请选择运营人员 | placeholder:请选择运营人员 | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter 业绩利润报表 by 请选择运营人员. |
| 选择日期 | placeholder:选择日期 | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter 业绩利润报表 by 选择日期. |
| 首页 | text:首页 | navigation | safe_execute_allowed | navigate_href | auto | Navigate from 业绩利润报表 to a related detail or analysis view. |
| 按回款时间 | 请选择 -> 按回款时间 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 按回款时间 from the 请选择 overlay on 业绩利润报表. |
| 按下单时间 | 请选择 -> 按下单时间 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 按下单时间 from the 请选择 overlay on 业绩利润报表. |
| 请选择 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择 overlay on 业绩利润报表. |
| 请选择运营人员 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择运营人员 overlay on 业绩利润报表. |

## ERP / 店铺利润报表

- Route: `/report-center/detail/shop`
- Sources: auto, overlay
- Actions: 12

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 保存配置 | text:保存配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 店铺利润报表; requires explicit confirmation before committing changes. |
| 导出报表 | text:导出报表 | button | confirmation_required_export | click_visible_dom_text | auto | Export or download data from 店铺利润报表; requires an explicit user request. |
| 用户菜单 | text:用户菜单 | button | safe_execute_allowed | click_visible_dom_text | auto | Open the current user/account menu. |
| 重置 | text:重置 | button | safe_execute_allowed | click_visible_dom_text | auto | Apply or clear filters on 店铺利润报表. |
| 重置配置 | text:重置配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 店铺利润报表; requires explicit confirmation before committing changes. |
| 选择店铺 | placeholder:选择店铺 | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter 店铺利润报表 by 选择店铺. |
| 选择日期 | placeholder:选择日期 | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter 店铺利润报表 by 选择日期. |
| 首页 | text:首页 | navigation | safe_execute_allowed | navigate_href | auto | Navigate from 店铺利润报表 to a related detail or analysis view. |
| 按回款时间 | 请选择 -> 按回款时间 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 按回款时间 from the 请选择 overlay on 店铺利润报表. |
| 按下单时间 | 请选择 -> 按下单时间 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 按下单时间 from the 请选择 overlay on 店铺利润报表. |
| 请选择 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择 overlay on 店铺利润报表. |
| 选择店铺 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 选择店铺 overlay on 店铺利润报表. |

## ERP / Shopee商品数据表

- Route: `/report-center/detail/shopeeGoods`
- Sources: auto
- Actions: 9

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 保存配置 | text:保存配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on Shopee商品数据表; requires explicit confirmation before committing changes. |
| 导出报表 | text:导出报表 | button | confirmation_required_export | click_visible_dom_text | auto | Export or download data from Shopee商品数据表; requires an explicit user request. |
| 用户菜单 | text:用户菜单 | button | safe_execute_allowed | click_visible_dom_text | auto | Open the current user/account menu. |
| 重置 | text:重置 | button | safe_execute_allowed | click_visible_dom_text | auto | Apply or clear filters on Shopee商品数据表. |
| 重置配置 | text:重置配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on Shopee商品数据表; requires explicit confirmation before committing changes. |
| 结束日期 | placeholder:结束日期 | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter Shopee商品数据表 by 结束日期. |
| 开始日期 | placeholder:开始日期 | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter Shopee商品数据表 by 开始日期. |
| 请选择商品 | placeholder:请选择商品 | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter Shopee商品数据表 by 请选择商品. |
| 首页 | text:首页 | navigation | safe_execute_allowed | navigate_href | auto | Navigate from Shopee商品数据表 to a related detail or analysis view. |

## ERP / Shopee店铺数据表

- Route: `/report-center/detail/shopeeShop`
- Sources: auto, overlay
- Actions: 11

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 保存配置 | text:保存配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on Shopee店铺数据表; requires explicit confirmation before committing changes. |
| 导出报表 | text:导出报表 | button | confirmation_required_export | click_visible_dom_text | auto | Export or download data from Shopee店铺数据表; requires an explicit user request. |
| 用户菜单 | text:用户菜单 | button | safe_execute_allowed | click_visible_dom_text | auto | Open the current user/account menu. |
| 重置 | text:重置 | button | safe_execute_allowed | click_visible_dom_text | auto | Apply or clear filters on Shopee店铺数据表. |
| 重置配置 | text:重置配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on Shopee店铺数据表; requires explicit confirmation before committing changes. |
| 结束日期 | placeholder:结束日期 | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter Shopee店铺数据表 by 结束日期. |
| 开始日期 | placeholder:开始日期 | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter Shopee店铺数据表 by 开始日期. |
| 选择店铺 | placeholder:选择店铺 | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter Shopee店铺数据表 by 选择店铺. |
| 首页 | text:首页 | navigation | safe_execute_allowed | navigate_href | auto | Navigate from Shopee店铺数据表 to a related detail or analysis view. |
| 请选择 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择 overlay on Shopee店铺数据表. |
| 选择店铺 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 选择店铺 overlay on Shopee店铺数据表. |

## ERP / 店铺表现看板

- Route: `/shop-data/performance-board`
- Sources: auto
- Actions: 5

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 保存配置 | text:保存配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 店铺表现看板; requires explicit confirmation before committing changes. |
| 用户菜单 | text:用户菜单 | button | safe_execute_allowed | click_visible_dom_text | auto | Open the current user/account menu. |
| 重置配置 | text:重置配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 店铺表现看板; requires explicit confirmation before committing changes. |
| 查看操作教程 | text:查看操作教程 | navigation | safe_execute_allowed | click_visible_dom_text | auto | Navigate from 店铺表现看板 to a related detail or analysis view. |
| 首页 | text:首页 | navigation | safe_execute_allowed | navigate_href | auto | Navigate from 店铺表现看板 to a related detail or analysis view. |

## ERP / 店铺表现分析

- Route: `/shop-data/performance-detail`
- Sources: auto
- Actions: 4

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 保存配置 | text:保存配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 店铺表现分析; requires explicit confirmation before committing changes. |
| 用户菜单 | text:用户菜单 | button | safe_execute_allowed | click_visible_dom_text | auto | Open the current user/account menu. |
| 重置配置 | text:重置配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 店铺表现分析; requires explicit confirmation before committing changes. |
| 首页 | text:首页 | navigation | safe_execute_allowed | navigate_href | auto | Navigate from 店铺表现分析 to a related detail or analysis view. |

## ERP / 授权失败

- Route: `/shop/auth-fail`
- Sources: auto
- Actions: 5

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 保存配置 | text:保存配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 授权失败; requires explicit confirmation before committing changes. |
| 返回 | text:返回 | button | safe_execute_allowed | click_visible_dom_text | auto | Navigate from 授权失败 to a related detail or analysis view. |
| 用户菜单 | text:用户菜单 | button | safe_execute_allowed | click_visible_dom_text | auto | Open the current user/account menu. |
| 重置配置 | text:重置配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 授权失败; requires explicit confirmation before committing changes. |
| 首页 | text:首页 | navigation | safe_execute_allowed | navigate_href | auto | Navigate from 授权失败 to a related detail or analysis view. |

## ERP / 授权结果

- Route: `/shop/auth`
- Sources: auto
- Actions: 5

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 保存配置 | text:保存配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 授权结果; requires explicit confirmation before committing changes. |
| 返回 | text:返回 | button | safe_execute_allowed | click_visible_dom_text | auto | Navigate from 授权结果 to a related detail or analysis view. |
| 用户菜单 | text:用户菜单 | button | safe_execute_allowed | click_visible_dom_text | auto | Open the current user/account menu. |
| 重置配置 | text:重置配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 授权结果; requires explicit confirmation before committing changes. |
| 首页 | text:首页 | navigation | safe_execute_allowed | navigate_href | auto | Navigate from 授权结果 to a related detail or analysis view. |

## ERP / 自定义费用

- Route: `/system/costom-fee`
- Sources: auto, dialog, overlay, row-action
- Actions: 23

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 批量导入自定义费用 | text:批量导入自定义费用 | batch_action | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 自定义费用; requires explicit confirmation before committing changes. |
| 批量删除 | text:批量删除 | batch_action | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 自定义费用; requires explicit confirmation before committing changes. |
| 保存配置 | text:保存配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 自定义费用; requires explicit confirmation before committing changes. |
| 编辑 | text:编辑 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 自定义费用; requires explicit confirmation before committing changes. |
| 删除 | text:删除 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 自定义费用; requires explicit confirmation before committing changes. |
| 搜索 | text:搜索 | button | safe_execute_allowed | click_visible_dom_text | auto | Apply or clear filters on 自定义费用. |
| 新增自定义费用 | text:新增自定义费用 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 自定义费用; requires explicit confirmation before committing changes. |
| 用户菜单 | text:用户菜单 | button | safe_execute_allowed | click_visible_dom_text | auto | Open the current user/account menu. |
| 重置 | text:重置 | button | safe_execute_allowed | click_visible_dom_text | auto | Apply or clear filters on 自定义费用. |
| 重置配置 | text:重置配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 自定义费用; requires explicit confirmation before committing changes. |
| 编辑取消 | 编辑 -> 取消 | dialog_button | safe_execute_allowed | click_trigger_selector_then_dialog_button_text | dialog | Use 取消 inside the 编辑 dialog/drawer on 自定义费用. |
| 编辑确定 | 编辑 -> 确定 | dialog_button | confirmation_required_write | click_trigger_selector_then_dialog_button_text | dialog | Use 确定 inside the 编辑 dialog/drawer on 自定义费用. |
| 新增自定义费用取消 | 新增自定义费用 -> 取消 | dialog_button | safe_execute_allowed | click_trigger_selector_then_dialog_button_text | dialog | Use 取消 inside the 新增自定义费用 dialog/drawer on 自定义费用. |
| 新增自定义费用确定 | 新增自定义费用 -> 确定 | dialog_button | confirmation_required_write | click_trigger_selector_then_dialog_button_text | dialog | Use 确定 inside the 新增自定义费用 dialog/drawer on 自定义费用. |
| 编辑 |  | dialog_opener | safe_execute_allowed | click_trigger_selector | dialog | Open the 编辑 dialog/drawer on 自定义费用; do not submit changes without explicit confirmation. |
| 新增自定义费用 |  | dialog_opener | safe_execute_allowed | click_trigger_selector | dialog | Open the 新增自定义费用 dialog/drawer on 自定义费用; do not submit changes without explicit confirmation. |
| 选择店铺 | placeholder:选择店铺 | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter 自定义费用 by 选择店铺. |
| 选择月 | placeholder:选择月 | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter 自定义费用 by 选择月. |
| 首页 | text:首页 | navigation | safe_execute_allowed | navigate_href | auto | Navigate from 自定义费用 to a related detail or analysis view. |
| 请选择 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择 overlay on 自定义费用. |
| 选择店铺 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 选择店铺 overlay on 自定义费用. |
| 操作编辑 | 操作 -> 编辑 | row_action | confirmation_required_write | click_first_matching_row_action_in_table | row-action | Use row action 编辑 in the 操作 column on 自定义费用. |
| 操作删除 | 操作 -> 删除 | row_action | confirmation_required_write | click_first_matching_row_action_in_table | row-action | Use row action 删除 in the 操作 column on 自定义费用. |

## ERP / 套餐开通记录

- Route: `/system/package-open-record`
- Sources: auto, overlay
- Actions: 9

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 保存配置 | text:保存配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 套餐开通记录; requires explicit confirmation before committing changes. |
| 用户菜单 | text:用户菜单 | button | safe_execute_allowed | click_visible_dom_text | auto | Open the current user/account menu. |
| 重置 | text:重置 | button | safe_execute_allowed | click_visible_dom_text | auto | Apply or clear filters on 套餐开通记录. |
| 重置配置 | text:重置配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 套餐开通记录; requires explicit confirmation before committing changes. |
| 结束日期 | placeholder:结束日期 | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter 套餐开通记录 by 结束日期. |
| 开始日期 | placeholder:开始日期 | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter 套餐开通记录 by 开始日期. |
| 租户名称/联系人/手机号 | placeholder:租户名称/联系人/手机号 | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter 套餐开通记录 by 租户名称/联系人/手机号. |
| 首页 | text:首页 | navigation | safe_execute_allowed | navigate_href | auto | Navigate from 套餐开通记录 to a related detail or analysis view. |
| 请选择 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择 overlay on 套餐开通记录. |

## ERP / 单量套餐

- Route: `/user/package`
- Sources: auto
- Actions: 5

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 保存配置 | text:保存配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 单量套餐; requires explicit confirmation before committing changes. |
| 用户菜单 | text:用户菜单 | button | safe_execute_allowed | click_visible_dom_text | auto | Open the current user/account menu. |
| 重置配置 | text:重置配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 单量套餐; requires explicit confirmation before committing changes. |
| 首页 | text:首页 | navigation | safe_execute_allowed | navigate_href | auto | Navigate from 单量套餐 to a related detail or analysis view. |
| 单量套餐 |  | tab | safe_execute_allowed | click_visible_action_text | auto | Switch 单量套餐 to the 单量套餐 tab/view. |

## Global / Global

- Route: ``
- Sources: curated
- Actions: 6

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 保存配置 | uia:保存配置 | button | confirmation_required_write | uia_locator | curated | Save current theme/layout configuration. |
| 重置配置 | uia:重置配置 | button | confirmation_required_write | uia_locator | curated | Reset theme/layout configuration. |
| ADS | uia:ADS | module_switch | safe_execute_allowed | uia_locator | curated | Switch to the advertising module before querying product ad performance. |
| BI | uia:BI | module_switch | safe_execute_allowed | uia_locator | curated | Switch to the BI/business intelligence module. |
| CRM | uia:CRM | module_switch | safe_execute_allowed | uia_locator | curated | Switch to CRM pages for creator management and outreach workflows. |
| ERP | uia:ERP | module_switch | safe_execute_allowed | uia_locator | curated | Switch to ERP operations pages such as orders, shops, products, finance, and warnings. |

## System / 下载中心

- Route: `/download/list`
- Sources: curated, overlay
- Actions: 5

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 重置 | text:重置 | button | safe_execute_allowed | click_visible_dom_text | curated | Clear current download-center filters. |
| 日期范围 | placeholders:开始日期/结束日期 | date_filter | safe_execute_allowed | input_or_filter_placeholder_list | curated | Filter download-center reports by date range. |
| 报告名称 | column:报表名称 | filter_input | safe_execute_allowed | input_or_filter_placeholder | curated | Search generated reports by report name. |
| 请选择 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择 overlay on 下载中心. |
| 操作 | column:操作 | row_operation | confirmation_required_export | row_context_required_column_header | curated | Operate on a generated report row, usually to download or open the generated file. Exact row button text still needs capture. |

## System / 首页

- Route: `/index/home`
- Sources: auto, overlay
- Actions: 16

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 保存配置 | text:保存配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 首页; requires explicit confirmation before committing changes. |
| 切换币种 | text:切换币种 | button | safe_execute_allowed | click_visible_dom_text | auto | Change the visible view setting on 首页. |
| 用户菜单 | text:用户菜单 | button | safe_execute_allowed | click_visible_dom_text | auto | Open the current user/account menu. |
| 重置配置 | text:重置配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 首页; requires explicit confirmation before committing changes. |
| 结束日期 | placeholder:结束日期 | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter 首页 by 结束日期. |
| 开始日期 | placeholder:开始日期 | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter 首页 by 开始日期. |
| 选择店铺 | placeholder:选择店铺 | filter_input | safe_execute_allowed | input_or_filter_placeholder | auto | Filter 首页 by 选择店铺. |
| 首页 | text:首页 | navigation | safe_execute_allowed | navigate_href | auto | Navigate from 首页 to a related detail or analysis view. |
| 按店铺 | 请选择 -> 按店铺 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 按店铺 from the 请选择 overlay on 首页. |
| 按负责人 | 请选择 -> 按负责人 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 按负责人 from the 请选择 overlay on 首页. |
| 按人员 | 请选择 -> 按人员 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 按人员 from the 请选择 overlay on 首页. |
| 店铺 | 请选择 -> 店铺 | overlay_item | manual_review | click_trigger_selector_then_overlay_item_text | overlay | Choose 店铺 from the 请选择 overlay on 首页. |
| 订单 | 请选择 -> 订单 | overlay_item | manual_review | click_trigger_selector_then_overlay_item_text | overlay | Choose 订单 from the 请选择 overlay on 首页. |
| 利润 | 请选择 -> 利润 | overlay_item | manual_review | click_trigger_selector_then_overlay_item_text | overlay | Choose 利润 from the 请选择 overlay on 首页. |
| 请选择 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择 overlay on 首页. |
| 选择店铺 |  | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 选择店铺 overlay on 首页. |

## System / 受限页面

- Route: `/index/noaccess`
- Sources: auto
- Actions: 4

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 保存配置 | text:保存配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 受限页面; requires explicit confirmation before committing changes. |
| 用户菜单 | text:用户菜单 | button | safe_execute_allowed | click_visible_dom_text | auto | Open the current user/account menu. |
| 重置配置 | text:重置配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 受限页面; requires explicit confirmation before committing changes. |
| 首页 | text:首页 | navigation | safe_execute_allowed | navigate_href | auto | Navigate from 受限页面 to a related detail or analysis view. |

## System / 套餐

- Route: `/index/thali`
- Sources: auto
- Actions: 4

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 保存配置 | text:保存配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 套餐; requires explicit confirmation before committing changes. |
| 用户菜单 | text:用户菜单 | button | safe_execute_allowed | click_visible_dom_text | auto | Open the current user/account menu. |
| 重置配置 | text:重置配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 套餐; requires explicit confirmation before committing changes. |
| 首页 | text:首页 | navigation | safe_execute_allowed | navigate_href | auto | Navigate from 套餐 to a related detail or analysis view. |
