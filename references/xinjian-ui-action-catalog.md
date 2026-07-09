# Xinjian UI Action Catalog

Generated from sanitized public 心舰 UI maps. Use this as a compact index of remembered pages, buttons, filters, overlays, dialogs, row actions, safety gates, and locator strategies.

## Totals

- Pages: 49
- Actions: 1117
- Global actions: 6

### Sources

| Source | Version | Pages | Actions |
| --- | --- | ---: | ---: |
| curated | 2026-07-08.2 | 10 | 63 |
| auto | 2026-07-09 | 48 | 844 |
| overlay | 2026-07-09 | 47 | 163 |
| dialog | 2026-07-09 | 47 | 41 |
| row-action | 2026-07-09 | 47 | 6 |
| table-header | generated | 0 | 82 |

### Safety

| Safety mode | Actions |
| --- | ---: |
| confirmation_required_export | 9 |
| confirmation_required_write | 83 |
| safe_execute_allowed | 1025 |

### Locator Strategies

| Locator strategy | Actions |
| --- | ---: |
| click_css_selector | 364 |
| click_first_matching_row_action_in_table | 6 |
| click_quick_tab_text_or_placeholder_list | 3 |
| click_trigger_selector | 101 |
| click_trigger_selector_then_dialog_button_text | 29 |
| click_trigger_selector_then_overlay_item_text | 71 |
| click_visible_action_text | 5 |
| click_visible_dom_text | 44 |
| click_visible_tab_text_from_list | 1 |
| input_or_filter_placeholder | 12 |
| input_or_filter_placeholder_list | 2 |
| navigate_href | 5 |
| read_table_column_header | 460 |
| row_context_required_column_header | 2 |
| row_context_required_dialog | 3 |
| uia_locator | 9 |

## Audit

- Manual-review actions: 0
- Map-only actions: 0
- Empty-locator actions: 0

## ADS / 广告详情

- Route: `/ad/group-detail`
- Sources: auto, curated, dialog, overlay, row-action, table-header
- Actions: 21

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 切换币种 | text:切换币种 | button | safe_execute_allowed | click_visible_dom_text | curated | Switch the displayed currency for ad detail metrics. |
| 切换币种 | text:切换币种 | button | safe_execute_allowed | click_css_selector | auto | Change the visible view setting on 广告详情. |
| 修改 | text:修改 | button | confirmation_required_write | click_visible_dom_text | curated | Open an edit flow for ad detail settings such as bid-related fields. Requires explicit confirmation before saving. |
| 修改 | text:修改 | button | confirmation_required_write | click_css_selector | auto | Open or run a write/configuration action on 广告详情; requires explicit confirmation before committing changes. |
| 日期范围 | tabs:今天/昨天/近7天/近30天; placeholders:开始日期/结束日期 | date_filter | safe_execute_allowed | click_quick_tab_text_or_placeholder_list | curated | Set the ad detail date range or use the visible quick tabs. |
| 修改关闭 | 修改 -> 关闭 | dialog_button | safe_execute_allowed | click_trigger_selector_then_dialog_button_text | dialog | Use 关闭 inside the 修改 dialog/drawer on 广告详情. |
| 修改取消 | 修改 -> 取消 | dialog_button | safe_execute_allowed | click_trigger_selector_then_dialog_button_text | dialog | Use 取消 inside the 修改 dialog/drawer on 广告详情. |
| 修改确定 | 修改 -> 确定 | dialog_button | confirmation_required_write | click_trigger_selector_then_dialog_button_text | dialog | Use 确定 inside the 修改 dialog/drawer on 广告详情. |
| 修改 | dialog_opener:修改 | dialog_opener | safe_execute_allowed | click_trigger_selector | dialog | Open the 修改 dialog/drawer on 广告详情; do not submit changes without explicit confirmation. |
| 结束日期 | placeholder:结束日期 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 广告详情 by 结束日期. |
| 开始日期 | placeholder:开始日期 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 广告详情 by 开始日期. |
| 今天 | 开始日期 -> 今天 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 今天 from the 开始日期 overlay on 广告详情. |
| 昨天 | 开始日期 -> 昨天 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 昨天 from the 开始日期 overlay on 广告详情. |
| 开始日期 | overlay_trigger:开始日期 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 开始日期 overlay on 广告详情. |
| 今天 | selector:div#tab-0 | tab | safe_execute_allowed | click_css_selector | auto | Switch 广告详情 to the 今天 tab/view. |
| 近30天 | selector:div#tab-3 | tab | safe_execute_allowed | click_css_selector | auto | Switch 广告详情 to the 近30天 tab/view. |
| 近7天 | selector:div#tab-2 | tab | safe_execute_allowed | click_css_selector | auto | Switch 广告详情 to the 近7天 tab/view. |
| 昨天 | selector:div#tab-1 | tab | safe_execute_allowed | click_css_selector | auto | Switch 广告详情 to the 昨天 tab/view. |
| 点击出价 | column:点击出价 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 广告详情 has the 点击出价 table column/metric. |
| 关键词 | column:关键词 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 广告详情 has the 关键词 table column/metric. |
| 关联版位 | column:关联版位 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 广告详情 has the 关联版位 table column/metric. |

## ADS / 创意详情

- Route: `/ad/originality-detail`
- Sources: auto, curated, dialog, overlay, row-action
- Actions: 32

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 应用 | text:应用 | batch_action | confirmation_required_write | click_visible_dom_text | curated | Apply the selected batch operation to selected creative records. Requires explicit confirmation. |
| 切换币种 | text:切换币种 | button | safe_execute_allowed | click_visible_dom_text | curated | Switch the displayed currency for creative detail metrics. |
| 切换币种 | text:切换币种 | button | safe_execute_allowed | click_css_selector | auto | Change the visible view setting on 创意详情. |
| 应用 | text:应用 | button | confirmation_required_write | click_css_selector | auto | Open or run a write/configuration action on 创意详情; requires explicit confirmation before committing changes. |
| 重置 | text:重置 | button | safe_execute_allowed | click_visible_dom_text | curated | Clear current creative-detail filters. |
| 重置 | text:重置 | button | safe_execute_allowed | click_css_selector | auto | Apply or clear filters on 创意详情. |
| 日期范围 | tabs:今天/昨天/近7天/近30天; placeholders:开始日期/结束日期 | date_filter | safe_execute_allowed | click_quick_tab_text_or_placeholder_list | curated | Set the creative detail date range or use the visible quick tabs. |
| 创意状态 | placeholder:请选择创意状态 | filter_dropdown | safe_execute_allowed | input_or_filter_placeholder | curated | Filter ad creatives by creative status. |
| 请选择创意状态 | text:请选择创意状态 | filter_dropdown | safe_execute_allowed | click_css_selector | auto | Filter 创意详情 by 请选择创意状态. |
| 选择批量操作 | text:选择批量操作 | filter_dropdown | safe_execute_allowed | click_css_selector | auto | Filter 创意详情 by 选择批量操作. |
| 结束日期 | placeholder:结束日期 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 创意详情 by 结束日期. |
| 开始日期 | placeholder:开始日期 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 创意详情 by 开始日期. |
| 请输入搜索内容 | placeholder:请输入搜索内容 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 创意详情 by 请输入搜索内容. |
| 请选择创意状态 | placeholder:请选择创意状态 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 创意详情 by 请选择创意状态. |
| 搜索内容 | placeholder:请输入搜索内容 | filter_input | safe_execute_allowed | input_or_filter_placeholder | curated | Search within creative detail records. |
| 选择批量操作 | placeholder:选择批量操作 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 创意详情 by 选择批量操作. |
| 按视频名称 | 请选择 -> 按视频名称 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 按视频名称 from the 请选择 overlay on 创意详情. |
| 按视频ID号 | 请选择 -> 按视频ID号 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 按视频ID号 from the 请选择 overlay on 创意详情. |
| 按Tiktok账号 | 请选择 -> 按Tiktok账号 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 按Tiktok账号 from the 请选择 overlay on 创意详情. |
| 今天 | 开始日期 -> 今天 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 今天 from the 开始日期 overlay on 创意详情. |
| 批量排除 | 选择批量操作 -> 批量排除 | overlay_item | confirmation_required_write | click_trigger_selector_then_overlay_item_text | overlay | Choose 批量排除 from the 选择批量操作 overlay on 创意详情. |
| 批量添加至广告计划 | 选择批量操作 -> 添加至广告计划 | overlay_item | confirmation_required_write | click_trigger_selector_then_overlay_item_text | overlay | Choose 添加至广告计划 from the 选择批量操作 overlay on 创意详情. |
| 昨天 | 开始日期 -> 昨天 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 昨天 from the 开始日期 overlay on 创意详情. |
| 开始日期 | overlay_trigger:开始日期 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 开始日期 overlay on 创意详情. |
| 请选择 | overlay_trigger:请选择 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择 overlay on 创意详情. |
| 请选择创意状态 | overlay_trigger:请选择创意状态 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择创意状态 overlay on 创意详情. |
| 选择批量操作 | overlay_trigger:选择批量操作 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 选择批量操作 overlay on 创意详情. |
| 今天 | selector:div#tab-0 | tab | safe_execute_allowed | click_css_selector | auto | Switch 创意详情 to the 今天 tab/view. |
| 近30天 | selector:div#tab-3 | tab | safe_execute_allowed | click_css_selector | auto | Switch 创意详情 to the 近30天 tab/view. |
| 近7天 | selector:div#tab-2 | tab | safe_execute_allowed | click_css_selector | auto | Switch 创意详情 to the 近7天 tab/view. |
| 昨天 | selector:div#tab-1 | tab | safe_execute_allowed | click_css_selector | auto | Switch 创意详情 to the 昨天 tab/view. |
| 操作 | column:操作 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 创意详情 has the 操作 table column/metric. |

## ADS / 店铺广告分析

- Route: `/ad/shop-detail`
- Sources: auto, curated, dialog, overlay, row-action, table-header
- Actions: 47

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 切换币种 | text:切换币种 | button | safe_execute_allowed | click_visible_dom_text | curated | Switch the displayed currency for advertising metrics. |
| 切换币种 | text:切换币种 | button | safe_execute_allowed | click_css_selector | auto | Change the visible view setting on 店铺广告分析. |
| 预警设置 | text:预警设置 | button | confirmation_required_write | click_visible_dom_text | curated | Open advertising balance warning settings. Requires explicit confirmation before saving changes. |
| 预警设置 | text:预警设置 | button | confirmation_required_write | click_css_selector | auto | Open or run a write/configuration action on 店铺广告分析; requires explicit confirmation before committing changes. |
| 重置 | text:重置 | button | safe_execute_allowed | click_visible_dom_text | curated | Clear current shop advertising analysis filters. |
| 重置 | text:重置 | button | safe_execute_allowed | click_css_selector | auto | Apply or clear filters on 店铺广告分析. |
| 日期范围 | tabs:今天/昨天/近7天/近30天; placeholders:开始日期/结束日期 | date_filter | safe_execute_allowed | click_quick_tab_text_or_placeholder_list | curated | Set the advertising analysis date range or use the visible quick tabs. |
| 预警设置关闭 | 预警设置 -> 关闭 | dialog_button | safe_execute_allowed | click_trigger_selector_then_dialog_button_text | dialog | Use 关闭 inside the 预警设置 dialog/drawer on 店铺广告分析. |
| 预警设置取消 | 预警设置 -> 取消 | dialog_button | safe_execute_allowed | click_trigger_selector_then_dialog_button_text | dialog | Use 取消 inside the 预警设置 dialog/drawer on 店铺广告分析. |
| 预警设置确定 | 预警设置 -> 确定 | dialog_button | confirmation_required_write | click_trigger_selector_then_dialog_button_text | dialog | Use 确定 inside the 预警设置 dialog/drawer on 店铺广告分析. |
| 预警设置 | dialog_opener:预警设置 | dialog_opener | safe_execute_allowed | click_trigger_selector | dialog | Open the 预警设置 dialog/drawer on 店铺广告分析; do not submit changes without explicit confirmation. |
| 结束日期 | placeholder:结束日期 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 店铺广告分析 by 结束日期. |
| 开始日期 | placeholder:开始日期 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 店铺广告分析 by 开始日期. |
| 选择店铺 | placeholder:选择店铺 | filter_input | safe_execute_allowed | input_or_filter_placeholder | curated | Filter shop-level advertising analysis by shop. |
| 选择店铺 | placeholder:选择店铺 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 店铺广告分析 by 选择店铺. |
| 按店铺 | 请选择 -> 按店铺 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 按店铺 from the 请选择 overlay on 店铺广告分析. |
| 按负责人 | 请选择 -> 按负责人 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 按负责人 from the 请选择 overlay on 店铺广告分析. |
| 按人员 | 请选择 -> 按人员 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 按人员 from the 请选择 overlay on 店铺广告分析. |
| 今天 | 开始日期 -> 今天 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 今天 from the 开始日期 overlay on 店铺广告分析. |
| 昨天 | 开始日期 -> 昨天 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 昨天 from the 开始日期 overlay on 店铺广告分析. |
| 开始日期 | overlay_trigger:开始日期 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 开始日期 overlay on 店铺广告分析. |
| 请选择 | overlay_trigger:请选择 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择 overlay on 店铺广告分析. |
| 选择店铺 | overlay_trigger:选择店铺 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 选择店铺 overlay on 店铺广告分析. |
| 行分析 | column:分析 | row_navigation | safe_execute_allowed | row_context_required_column_header | curated | Open a row-level advertising analysis/detail page for the selected shop or ad entity. |
| 今天 | selector:div#tab-0 | tab | safe_execute_allowed | click_css_selector | auto | Switch 店铺广告分析 to the 今天 tab/view. |
| 近30天 | selector:div#tab-3 | tab | safe_execute_allowed | click_css_selector | auto | Switch 店铺广告分析 to the 近30天 tab/view. |
| 近7天 | selector:div#tab-2 | tab | safe_execute_allowed | click_css_selector | auto | Switch 店铺广告分析 to the 近7天 tab/view. |
| 平台标签 | tabs:Shopee/Lazada/Tiktok | tab | safe_execute_allowed | click_visible_tab_text_from_list | curated | Switch the shop advertising analysis table between platform tabs. |
| 昨天 | selector:div#tab-1 | tab | safe_execute_allowed | click_css_selector | auto | Switch 店铺广告分析 to the 昨天 tab/view. |
| Lazada | selector:div#tab-Lazada | tab | safe_execute_allowed | click_css_selector | auto | Switch 店铺广告分析 to the Lazada tab/view. |
| Shopee | selector:div#tab-Shopee | tab | safe_execute_allowed | click_css_selector | auto | Switch 店铺广告分析 to the Shopee tab/view. |
| Tiktok | selector:div#tab-Tiktok | tab | safe_execute_allowed | click_css_selector | auto | Switch 店铺广告分析 to the Tiktok tab/view. |
| 操作 | column:操作 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺广告分析 has the 操作 table column/metric. |
| 点击量 | column:点击量 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 店铺广告分析 has the 点击量 table column/metric. |
| 点击率 | column:点击率 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 店铺广告分析 has the 点击率 table column/metric. |
| 店铺 | column:店铺 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 店铺广告分析 has the 店铺 table column/metric. |
| 分析 | column:分析 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 店铺广告分析 has the 分析 table column/metric. |
| 广告订单量 | column:广告订单量 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 店铺广告分析 has the 广告订单量 table column/metric. |
| 广告花费 | column:广告花费 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 店铺广告分析 has the 广告花费 table column/metric. |
| 广告销量 | column:广告销量 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 店铺广告分析 has the 广告销量 table column/metric. |
| 广告销售额 | column:广告销售额 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 店铺广告分析 has the 广告销售额 table column/metric. |
| 广告余额预警设置 | column:广告余额预警设置 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 店铺广告分析 has the 广告余额预警设置 table column/metric. |
| 平均下单成本 | column:平均下单成本 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 店铺广告分析 has the 平均下单成本 table column/metric. |
| 展现量 | column:展现量 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 店铺广告分析 has the 展现量 table column/metric. |
| 转化率 | column:转化率 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 店铺广告分析 has the 转化率 table column/metric. |
| ACoS | column:ACoS | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 店铺广告分析 has the ACoS table column/metric. |
| ROAS | column:ROAS | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 店铺广告分析 has the ROAS table column/metric. |

## ADS / 广告规则执行日志

- Route: `/erp/ads/rule-log`
- Sources: auto, curated, dialog, overlay, row-action, table-header
- Actions: 28

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 导出日志 | text:导出日志 | button | confirmation_required_export | click_css_selector | auto | Export or download data from 广告规则执行日志; requires an explicit user request. |
| 导出日志 | text:导出日志 | button | confirmation_required_export | click_visible_dom_text | curated | Export advertising rule execution logs. Requires explicit user request/confirmation. |
| 重置 | text:重置 | button | safe_execute_allowed | click_css_selector | auto | Apply or clear filters on 广告规则执行日志. |
| 重置 | text:重置 | button | safe_execute_allowed | click_visible_dom_text | curated | Clear current rule-log filters. |
| 日期范围 | column:执行时间 | date_filter | safe_execute_allowed | input_or_filter_placeholder_list | curated | Filter rule logs by execution date range. |
| 结束日期 | placeholder:结束日期 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 广告规则执行日志 by 结束日期. |
| 开始日期 | placeholder:开始日期 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 广告规则执行日志 by 开始日期. |
| 请输入搜索内容 | placeholder:请输入搜索内容 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 广告规则执行日志 by 请输入搜索内容. |
| 搜索内容 | placeholder:请输入搜索内容 | filter_input | safe_execute_allowed | input_or_filter_placeholder | curated | Search advertising rule execution logs. |
| 选择店铺 | placeholder:选择店铺 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 广告规则执行日志 by 选择店铺. |
| 选择店铺 | placeholder:选择店铺 | filter_input | safe_execute_allowed | input_or_filter_placeholder | curated | Filter advertising rule execution logs by shop. |
| 详情 | text:详情 | navigation | safe_execute_allowed | click_css_selector | auto | Navigate from 广告规则执行日志 to a related detail or analysis view. |
| 成功 | 请选择 -> 成功 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 成功 from the 请选择 overlay on 广告规则执行日志. |
| 今天 | 开始日期 -> 今天 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 今天 from the 开始日期 overlay on 广告规则执行日志. |
| 失败 | 请选择 -> 失败 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 失败 from the 请选择 overlay on 广告规则执行日志. |
| 昨天 | 开始日期 -> 昨天 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 昨天 from the 开始日期 overlay on 广告规则执行日志. |
| 开始日期 | overlay_trigger:开始日期 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 开始日期 overlay on 广告规则执行日志. |
| 请选择 | overlay_trigger:请选择 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择 overlay on 广告规则执行日志. |
| 选择店铺 | overlay_trigger:选择店铺 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 选择店铺 overlay on 广告规则执行日志. |
| 详情 | column:操作 | row_navigation | safe_execute_allowed | click_visible_dom_text | curated | Open detail for a visible advertising rule execution log row. |
| 变更 | column:变更 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 广告规则执行日志 has the 变更 table column/metric. |
| 操作 | column:操作 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 广告规则执行日志 has the 操作 table column/metric. |
| 触发条件 | column:触发条件 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 广告规则执行日志 has the 触发条件 table column/metric. |
| 广告信息 | column:广告信息 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 广告规则执行日志 has the 广告信息 table column/metric. |
| 规则名称 | column:规则名称 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 广告规则执行日志 has the 规则名称 table column/metric. |
| 执行操作 | column:执行操作 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 广告规则执行日志 has the 执行操作 table column/metric. |
| 执行结果 | column:执行结果 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 广告规则执行日志 has the 执行结果 table column/metric. |
| 执行时间 | column:执行时间 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 广告规则执行日志 has the 执行时间 table column/metric. |

## AI / 创作会话

- Route: `/ai/talk`
- Sources: auto, dialog, overlay, row-action
- Actions: 4

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 保存配置 | text:保存配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 创作会话; requires explicit confirmation before committing changes. |
| 用户菜单 | text:用户菜单 | button | safe_execute_allowed | click_visible_dom_text | auto | Open the current user/account menu. |
| 重置配置 | text:重置配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 创作会话; requires explicit confirmation before committing changes. |
| 首页 | text:首页 | navigation | safe_execute_allowed | navigate_href | auto | Navigate from 创作会话 to a related detail or analysis view. |

## BI / 售后单管理

- Route: `/bi/afterSalesOrder/index`
- Sources: auto, dialog, overlay, row-action
- Actions: 51

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 批量操作 | text:批量操作 | batch_action | confirmation_required_write | click_css_selector | auto | Open or run a write/configuration action on 售后单管理; requires explicit confirmation before committing changes. |
| 导入售后单 | text:导入售后单 | button | confirmation_required_write | click_css_selector | auto | Open or run a write/configuration action on 售后单管理; requires explicit confirmation before committing changes. |
| 切换币种 | text:切换币种 | button | safe_execute_allowed | click_css_selector | auto | Change the visible view setting on 售后单管理. |
| 搜索 | text:搜索 | button | safe_execute_allowed | click_css_selector | auto | Apply or clear filters on 售后单管理. |
| 新增售后单 | text:新增售后单 | button | confirmation_required_write | click_css_selector | auto | Open or run a write/configuration action on 售后单管理; requires explicit confirmation before committing changes. |
| 重置 | text:重置 | button | safe_execute_allowed | click_css_selector | auto | Apply or clear filters on 售后单管理. |
| 新增售后单取消 | 新增售后单 -> 取消 | dialog_button | safe_execute_allowed | click_trigger_selector_then_dialog_button_text | dialog | Use 取消 inside the 新增售后单 dialog/drawer on 售后单管理. |
| 新增售后单确定 | 新增售后单 -> 确定 | dialog_button | confirmation_required_write | click_trigger_selector_then_dialog_button_text | dialog | Use 确定 inside the 新增售后单 dialog/drawer on 售后单管理. |
| 新增售后单添加补发 | 新增售后单 -> 添加补发 | dialog_button | confirmation_required_write | click_trigger_selector_then_dialog_button_text | dialog | Use 添加补发 inside the 新增售后单 dialog/drawer on 售后单管理. |
| 新增售后单 | dialog_opener:新增售后单 | dialog_opener | safe_execute_allowed | click_trigger_selector | dialog | Open the 新增售后单 dialog/drawer on 售后单管理; do not submit changes without explicit confirmation. |
| 结束日期 | placeholder:结束日期 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 售后单管理 by 结束日期. |
| 开始日期 | placeholder:开始日期 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 售后单管理 by 开始日期. |
| 请输入订单号（双击批量搜索） | placeholder:请输入订单号（双击批量搜索） | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 售后单管理 by 请输入订单号（双击批量搜索）. |
| 选择店铺 | placeholder:选择店铺 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 售后单管理 by 选择店铺. |
| 今天 | 开始日期 -> 今天 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 今天 from the 开始日期 overlay on 售后单管理. |
| 昨天 | 开始日期 -> 昨天 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 昨天 from the 开始日期 overlay on 售后单管理. |
| 开始日期 | overlay_trigger:开始日期 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 开始日期 overlay on 售后单管理. |
| 批量操作 | overlay_trigger:批量操作 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 批量操作 overlay on 售后单管理. |
| 请选择 | overlay_trigger:请选择 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择 overlay on 售后单管理. |
| 选择店铺 | overlay_trigger:选择店铺 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 选择店铺 overlay on 售后单管理. |
| 补发加补优惠券 | text:补发加补优惠券 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 售后单管理 to the 补发加补优惠券 tab/view. |
| 补发加赔偿 | text:补发加赔偿 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 售后单管理 to the 补发加赔偿 tab/view. |
| 补发商品 | text:补发商品 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 售后单管理 to the 补发商品 tab/view. |
| 补优惠券 | text:补优惠券 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 售后单管理 to the 补优惠券 tab/view. |
| 换货 | text:换货 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 售后单管理 to the 换货 tab/view. |
| 仅退款 | text:仅退款 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 售后单管理 to the 仅退款 tab/view. |
| 全部 | text:全部 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 售后单管理 to the 全部 tab/view. |
| 退货退款 | text:退货退款 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 售后单管理 to the 退货退款 tab/view. |
| 退款加优惠券 | text:退款加优惠券 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 售后单管理 to the 退款加优惠券 tab/view. |
| 未确定方案 | text:未确定方案 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 售后单管理 to the 未确定方案 tab/view. |
| 线下退款 | text:线下退款 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 售后单管理 to the 线下退款 tab/view. |
| 商品售后统计 | selector:div#tab-productStats | tab | safe_execute_allowed | click_css_selector | auto | Switch 售后单管理 to the 商品售后统计 tab/view. |
| 售后单 | selector:div#tab-list | tab | safe_execute_allowed | click_css_selector | auto | Switch 售后单管理 to the 售后单 tab/view. |
| 售后专项统计 | selector:div#tab-reissueStats | tab | safe_execute_allowed | click_css_selector | auto | Switch 售后单管理 to the 售后专项统计 tab/view. |
| 数据概览 | selector:div#tab-overview | tab | safe_execute_allowed | click_css_selector | auto | Switch 售后单管理 to the 数据概览 tab/view. |
| 包裹信息 | column:包裹信息 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 售后单管理 has the 包裹信息 table column/metric. |
| 备注 | column:备注 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 售后单管理 has the 备注 table column/metric. |
| 标签 | column:标签 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 售后单管理 has the 标签 table column/metric. |
| 操作 | column:操作 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 售后单管理 has the 操作 table column/metric. |
| 创建人 | column:创建人 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 售后单管理 has the 创建人 table column/metric. |
| 创建时间 | column:创建时间 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 售后单管理 has the 创建时间 table column/metric. |
| 订单实付金额 | column:订单实付金额 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 售后单管理 has the 订单实付金额 table column/metric. |
| 订单信息 | column:订单信息 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 售后单管理 has the 订单信息 table column/metric. |
| 附件 | column:附件 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 售后单管理 has the 附件 table column/metric. |
| 换货明细 | column:换货明细 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 售后单管理 has the 换货明细 table column/metric. |
| 售后方案 | column:售后方案 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 售后单管理 has the 售后方案 table column/metric. |
| 售后金额 | column:售后金额 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 售后单管理 has the 售后金额 table column/metric. |
| 售后明细 | column:售后明细 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 售后单管理 has the 售后明细 table column/metric. |
| 售后时间 | column:售后时间 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 售后单管理 has the 售后时间 table column/metric. |
| 售后原因 | column:售后原因 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 售后单管理 has the 售后原因 table column/metric. |
| 状态 | column:状态 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 售后单管理 has the 状态 table column/metric. |

## BI / 推送监控

- Route: `/bi/monitor/pushFlowStats`
- Sources: auto, dialog, overlay, row-action
- Actions: 24

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 刷新 Top10 | text:刷新 Top10 | button | safe_execute_allowed | click_css_selector | auto | Change the visible view setting on 推送监控. |
| 刷新 | text:刷新 | button | safe_execute_allowed | click_css_selector | auto | Change the visible view setting on 推送监控. |
| 刷新同步详情 | text:刷新同步详情 | navigation | safe_execute_allowed | click_css_selector | auto | Navigate from 推送监控 to a related detail or analysis view. |
| 待处理超时 | selector:div#tab-pending | tab | safe_execute_allowed | click_css_selector | auto | Switch 推送监控 to the 待处理超时 tab/view. |
| 订单同步 | selector:div#tab-orderSync | tab | safe_execute_allowed | click_css_selector | auto | Switch 推送监控 to the 订单同步 tab/view. |
| 拉单店铺 | selector:div#tab-requestShop | tab | safe_execute_allowed | click_css_selector | auto | Switch 推送监控 to the 拉单店铺 tab/view. |
| 拉单租户 | selector:div#tab-requestTenant | tab | safe_execute_allowed | click_css_selector | auto | Switch 推送监控 to the 拉单租户 tab/view. |
| 平台推送 | selector:div#tab-platformPush | tab | safe_execute_allowed | click_css_selector | auto | Switch 推送监控 to the 平台推送 tab/view. |
| 普通队列 | selector:div#tab-normal | tab | safe_execute_allowed | click_css_selector | auto | Switch 推送监控 to the 普通队列 tab/view. |
| 入库店铺 | selector:div#tab-saveShop | tab | safe_execute_allowed | click_css_selector | auto | Switch 推送监控 to the 入库店铺 tab/view. |
| 入库租户 | selector:div#tab-saveTenant | tab | safe_execute_allowed | click_css_selector | auto | Switch 推送监控 to the 入库租户 tab/view. |
| 同步点落后 | selector:div#tab-checkpoint | tab | safe_execute_allowed | click_css_selector | auto | Switch 推送监控 to the 同步点落后 tab/view. |
| 优先队列 | selector:div#tab-prior | tab | safe_execute_allowed | click_css_selector | auto | Switch 推送监控 to the 优先队列 tab/view. |
| 执行中超时 | selector:div#tab-working | tab | safe_execute_allowed | click_css_selector | auto | Switch 推送监控 to the 执行中超时 tab/view. |
| 待处理时长 | column:待处理时长 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 推送监控 has the 待处理时长 table column/metric. |
| 店铺 | column:店铺 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 推送监控 has the 店铺 table column/metric. |
| 风险 | column:风险 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 推送监控 has the 风险 table column/metric. |
| 含义 | column:含义 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 推送监控 has the 含义 table column/metric. |
| 类型/重试 | column:类型/重试 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 推送监控 has the 类型/重试 table column/metric. |
| 每秒 | column:每秒 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 推送监控 has the 每秒 table column/metric. |
| 名称 | column:名称 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 推送监控 has the 名称 table column/metric. |
| 平台/国家 | column:平台/国家 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 推送监控 has the 平台/国家 table column/metric. |
| 数量 | column:数量 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 推送监控 has the 数量 table column/metric. |
| 所属租户 | column:所属租户 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 推送监控 has the 所属租户 table column/metric. |

## BI / 售后单管理

- Route: `/bi/operationCenter/afterSaleOrder/index`
- Sources: auto, dialog, overlay, row-action
- Actions: 51

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 批量操作 | text:批量操作 | batch_action | confirmation_required_write | click_css_selector | auto | Open or run a write/configuration action on 售后单管理; requires explicit confirmation before committing changes. |
| 导入售后单 | text:导入售后单 | button | confirmation_required_write | click_css_selector | auto | Open or run a write/configuration action on 售后单管理; requires explicit confirmation before committing changes. |
| 切换币种 | text:切换币种 | button | safe_execute_allowed | click_css_selector | auto | Change the visible view setting on 售后单管理. |
| 搜索 | text:搜索 | button | safe_execute_allowed | click_css_selector | auto | Apply or clear filters on 售后单管理. |
| 新增售后单 | text:新增售后单 | button | confirmation_required_write | click_css_selector | auto | Open or run a write/configuration action on 售后单管理; requires explicit confirmation before committing changes. |
| 重置 | text:重置 | button | safe_execute_allowed | click_css_selector | auto | Apply or clear filters on 售后单管理. |
| 新增售后单取消 | 新增售后单 -> 取消 | dialog_button | safe_execute_allowed | click_trigger_selector_then_dialog_button_text | dialog | Use 取消 inside the 新增售后单 dialog/drawer on 售后单管理. |
| 新增售后单确定 | 新增售后单 -> 确定 | dialog_button | confirmation_required_write | click_trigger_selector_then_dialog_button_text | dialog | Use 确定 inside the 新增售后单 dialog/drawer on 售后单管理. |
| 新增售后单添加补发 | 新增售后单 -> 添加补发 | dialog_button | confirmation_required_write | click_trigger_selector_then_dialog_button_text | dialog | Use 添加补发 inside the 新增售后单 dialog/drawer on 售后单管理. |
| 新增售后单 | dialog_opener:新增售后单 | dialog_opener | safe_execute_allowed | click_trigger_selector | dialog | Open the 新增售后单 dialog/drawer on 售后单管理; do not submit changes without explicit confirmation. |
| 结束日期 | placeholder:结束日期 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 售后单管理 by 结束日期. |
| 开始日期 | placeholder:开始日期 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 售后单管理 by 开始日期. |
| 请输入订单号（双击批量搜索） | placeholder:请输入订单号（双击批量搜索） | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 售后单管理 by 请输入订单号（双击批量搜索）. |
| 选择店铺 | placeholder:选择店铺 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 售后单管理 by 选择店铺. |
| 今天 | 开始日期 -> 今天 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 今天 from the 开始日期 overlay on 售后单管理. |
| 昨天 | 开始日期 -> 昨天 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 昨天 from the 开始日期 overlay on 售后单管理. |
| 开始日期 | overlay_trigger:开始日期 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 开始日期 overlay on 售后单管理. |
| 批量操作 | overlay_trigger:批量操作 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 批量操作 overlay on 售后单管理. |
| 请选择 | overlay_trigger:请选择 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择 overlay on 售后单管理. |
| 选择店铺 | overlay_trigger:选择店铺 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 选择店铺 overlay on 售后单管理. |
| 补发加补优惠券 | text:补发加补优惠券 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 售后单管理 to the 补发加补优惠券 tab/view. |
| 补发加赔偿 | text:补发加赔偿 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 售后单管理 to the 补发加赔偿 tab/view. |
| 补发商品 | text:补发商品 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 售后单管理 to the 补发商品 tab/view. |
| 补优惠券 | text:补优惠券 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 售后单管理 to the 补优惠券 tab/view. |
| 换货 | text:换货 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 售后单管理 to the 换货 tab/view. |
| 仅退款 | text:仅退款 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 售后单管理 to the 仅退款 tab/view. |
| 全部 | text:全部 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 售后单管理 to the 全部 tab/view. |
| 退货退款 | text:退货退款 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 售后单管理 to the 退货退款 tab/view. |
| 退款加优惠券 | text:退款加优惠券 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 售后单管理 to the 退款加优惠券 tab/view. |
| 未确定方案 | text:未确定方案 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 售后单管理 to the 未确定方案 tab/view. |
| 线下退款 | text:线下退款 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 售后单管理 to the 线下退款 tab/view. |
| 商品售后统计 | selector:div#tab-productStats | tab | safe_execute_allowed | click_css_selector | auto | Switch 售后单管理 to the 商品售后统计 tab/view. |
| 售后单 | selector:div#tab-list | tab | safe_execute_allowed | click_css_selector | auto | Switch 售后单管理 to the 售后单 tab/view. |
| 售后专项统计 | selector:div#tab-reissueStats | tab | safe_execute_allowed | click_css_selector | auto | Switch 售后单管理 to the 售后专项统计 tab/view. |
| 数据概览 | selector:div#tab-overview | tab | safe_execute_allowed | click_css_selector | auto | Switch 售后单管理 to the 数据概览 tab/view. |
| 包裹信息 | column:包裹信息 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 售后单管理 has the 包裹信息 table column/metric. |
| 备注 | column:备注 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 售后单管理 has the 备注 table column/metric. |
| 标签 | column:标签 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 售后单管理 has the 标签 table column/metric. |
| 操作 | column:操作 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 售后单管理 has the 操作 table column/metric. |
| 创建人 | column:创建人 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 售后单管理 has the 创建人 table column/metric. |
| 创建时间 | column:创建时间 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 售后单管理 has the 创建时间 table column/metric. |
| 订单实付金额 | column:订单实付金额 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 售后单管理 has the 订单实付金额 table column/metric. |
| 订单信息 | column:订单信息 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 售后单管理 has the 订单信息 table column/metric. |
| 附件 | column:附件 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 售后单管理 has the 附件 table column/metric. |
| 换货明细 | column:换货明细 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 售后单管理 has the 换货明细 table column/metric. |
| 售后方案 | column:售后方案 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 售后单管理 has the 售后方案 table column/metric. |
| 售后金额 | column:售后金额 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 售后单管理 has the 售后金额 table column/metric. |
| 售后明细 | column:售后明细 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 售后单管理 has the 售后明细 table column/metric. |
| 售后时间 | column:售后时间 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 售后单管理 has the 售后时间 table column/metric. |
| 售后原因 | column:售后原因 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 售后单管理 has the 售后原因 table column/metric. |
| 状态 | column:状态 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 售后单管理 has the 状态 table column/metric. |

## BI / 售后单管理

- Route: `/bi/operationCenter/afterSalesOrder/index`
- Sources: auto, dialog, overlay, row-action
- Actions: 51

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 批量操作 | text:批量操作 | batch_action | confirmation_required_write | click_css_selector | auto | Open or run a write/configuration action on 售后单管理; requires explicit confirmation before committing changes. |
| 导入售后单 | text:导入售后单 | button | confirmation_required_write | click_css_selector | auto | Open or run a write/configuration action on 售后单管理; requires explicit confirmation before committing changes. |
| 切换币种 | text:切换币种 | button | safe_execute_allowed | click_css_selector | auto | Change the visible view setting on 售后单管理. |
| 搜索 | text:搜索 | button | safe_execute_allowed | click_css_selector | auto | Apply or clear filters on 售后单管理. |
| 新增售后单 | text:新增售后单 | button | confirmation_required_write | click_css_selector | auto | Open or run a write/configuration action on 售后单管理; requires explicit confirmation before committing changes. |
| 重置 | text:重置 | button | safe_execute_allowed | click_css_selector | auto | Apply or clear filters on 售后单管理. |
| 新增售后单取消 | 新增售后单 -> 取消 | dialog_button | safe_execute_allowed | click_trigger_selector_then_dialog_button_text | dialog | Use 取消 inside the 新增售后单 dialog/drawer on 售后单管理. |
| 新增售后单确定 | 新增售后单 -> 确定 | dialog_button | confirmation_required_write | click_trigger_selector_then_dialog_button_text | dialog | Use 确定 inside the 新增售后单 dialog/drawer on 售后单管理. |
| 新增售后单添加补发 | 新增售后单 -> 添加补发 | dialog_button | confirmation_required_write | click_trigger_selector_then_dialog_button_text | dialog | Use 添加补发 inside the 新增售后单 dialog/drawer on 售后单管理. |
| 新增售后单 | dialog_opener:新增售后单 | dialog_opener | safe_execute_allowed | click_trigger_selector | dialog | Open the 新增售后单 dialog/drawer on 售后单管理; do not submit changes without explicit confirmation. |
| 结束日期 | placeholder:结束日期 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 售后单管理 by 结束日期. |
| 开始日期 | placeholder:开始日期 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 售后单管理 by 开始日期. |
| 请输入订单号（双击批量搜索） | placeholder:请输入订单号（双击批量搜索） | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 售后单管理 by 请输入订单号（双击批量搜索）. |
| 选择店铺 | placeholder:选择店铺 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 售后单管理 by 选择店铺. |
| 今天 | 开始日期 -> 今天 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 今天 from the 开始日期 overlay on 售后单管理. |
| 昨天 | 开始日期 -> 昨天 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 昨天 from the 开始日期 overlay on 售后单管理. |
| 开始日期 | overlay_trigger:开始日期 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 开始日期 overlay on 售后单管理. |
| 批量操作 | overlay_trigger:批量操作 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 批量操作 overlay on 售后单管理. |
| 请选择 | overlay_trigger:请选择 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择 overlay on 售后单管理. |
| 选择店铺 | overlay_trigger:选择店铺 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 选择店铺 overlay on 售后单管理. |
| 补发加补优惠券 | text:补发加补优惠券 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 售后单管理 to the 补发加补优惠券 tab/view. |
| 补发加赔偿 | text:补发加赔偿 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 售后单管理 to the 补发加赔偿 tab/view. |
| 补发商品 | text:补发商品 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 售后单管理 to the 补发商品 tab/view. |
| 补优惠券 | text:补优惠券 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 售后单管理 to the 补优惠券 tab/view. |
| 换货 | text:换货 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 售后单管理 to the 换货 tab/view. |
| 仅退款 | text:仅退款 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 售后单管理 to the 仅退款 tab/view. |
| 全部 | text:全部 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 售后单管理 to the 全部 tab/view. |
| 退货退款 | text:退货退款 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 售后单管理 to the 退货退款 tab/view. |
| 退款加优惠券 | text:退款加优惠券 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 售后单管理 to the 退款加优惠券 tab/view. |
| 未确定方案 | text:未确定方案 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 售后单管理 to the 未确定方案 tab/view. |
| 线下退款 | text:线下退款 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 售后单管理 to the 线下退款 tab/view. |
| 商品售后统计 | selector:div#tab-productStats | tab | safe_execute_allowed | click_css_selector | auto | Switch 售后单管理 to the 商品售后统计 tab/view. |
| 售后单 | selector:div#tab-list | tab | safe_execute_allowed | click_css_selector | auto | Switch 售后单管理 to the 售后单 tab/view. |
| 售后专项统计 | selector:div#tab-reissueStats | tab | safe_execute_allowed | click_css_selector | auto | Switch 售后单管理 to the 售后专项统计 tab/view. |
| 数据概览 | selector:div#tab-overview | tab | safe_execute_allowed | click_css_selector | auto | Switch 售后单管理 to the 数据概览 tab/view. |
| 包裹信息 | column:包裹信息 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 售后单管理 has the 包裹信息 table column/metric. |
| 备注 | column:备注 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 售后单管理 has the 备注 table column/metric. |
| 标签 | column:标签 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 售后单管理 has the 标签 table column/metric. |
| 操作 | column:操作 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 售后单管理 has the 操作 table column/metric. |
| 创建人 | column:创建人 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 售后单管理 has the 创建人 table column/metric. |
| 创建时间 | column:创建时间 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 售后单管理 has the 创建时间 table column/metric. |
| 订单实付金额 | column:订单实付金额 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 售后单管理 has the 订单实付金额 table column/metric. |
| 订单信息 | column:订单信息 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 售后单管理 has the 订单信息 table column/metric. |
| 附件 | column:附件 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 售后单管理 has the 附件 table column/metric. |
| 换货明细 | column:换货明细 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 售后单管理 has the 换货明细 table column/metric. |
| 售后方案 | column:售后方案 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 售后单管理 has the 售后方案 table column/metric. |
| 售后金额 | column:售后金额 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 售后单管理 has the 售后金额 table column/metric. |
| 售后明细 | column:售后明细 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 售后单管理 has the 售后明细 table column/metric. |
| 售后时间 | column:售后时间 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 售后单管理 has the 售后时间 table column/metric. |
| 售后原因 | column:售后原因 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 售后单管理 has the 售后原因 table column/metric. |
| 状态 | column:状态 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 售后单管理 has the 状态 table column/metric. |

## BI / 店铺利润分析详情

- Route: `/bi/profit/detail`
- Sources: auto, dialog, overlay, row-action
- Actions: 12

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 切换到汇总视图 | text:切换到汇总视图 | button | safe_execute_allowed | click_css_selector | auto | Change the visible view setting on 店铺利润分析详情. |
| 重置 | text:重置 | button | safe_execute_allowed | click_css_selector | auto | Apply or clear filters on 店铺利润分析详情. |
| 结束日期 | placeholder:结束日期 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 店铺利润分析详情 by 结束日期. |
| 开始日期 | placeholder:开始日期 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 店铺利润分析详情 by 开始日期. |
| 今天 | 开始日期 -> 今天 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 今天 from the 开始日期 overlay on 店铺利润分析详情. |
| 昨天 | 开始日期 -> 昨天 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 昨天 from the 开始日期 overlay on 店铺利润分析详情. |
| 开始日期 | overlay_trigger:开始日期 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 开始日期 overlay on 店铺利润分析详情. |
| 今天 | selector:div#tab-0 | tab | safe_execute_allowed | click_css_selector | auto | Switch 店铺利润分析详情 to the 今天 tab/view. |
| 近30天 | selector:div#tab-3 | tab | safe_execute_allowed | click_css_selector | auto | Switch 店铺利润分析详情 to the 近30天 tab/view. |
| 近7天 | selector:div#tab-2 | tab | safe_execute_allowed | click_css_selector | auto | Switch 店铺利润分析详情 to the 近7天 tab/view. |
| 昨天 | selector:div#tab-1 | tab | safe_execute_allowed | click_css_selector | auto | Switch 店铺利润分析详情 to the 昨天 tab/view. |
| 日期 | column:日期 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺利润分析详情 has the 日期 table column/metric. |

## BI / 商品复购分析报告详情

- Route: `/user-analyze/detail`
- Sources: auto, dialog, overlay, row-action
- Actions: 13

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 结束日期 | placeholder:结束日期 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 商品复购分析报告详情 by 结束日期. |
| 开始日期 | placeholder:开始日期 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 商品复购分析报告详情 by 开始日期. |
| 今天 | 开始日期 -> 今天 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 今天 from the 开始日期 overlay on 商品复购分析报告详情. |
| 昨天 | 开始日期 -> 昨天 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 昨天 from the 开始日期 overlay on 商品复购分析报告详情. |
| 开始日期 | overlay_trigger:开始日期 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 开始日期 overlay on 商品复购分析报告详情. |
| 产品规格 | column:产品规格 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品复购分析报告详情 has the 产品规格 table column/metric. |
| 订单复购率 | column:订单复购率 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品复购分析报告详情 has the 订单复购率 table column/metric. |
| 复购订单数 | column:复购订单数 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品复购分析报告详情 has the 复购订单数 table column/metric. |
| 复购用户数 | column:复购用户数 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品复购分析报告详情 has the 复购用户数 table column/metric. |
| 平均复购周期(天) | column:平均复购周期(天) | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品复购分析报告详情 has the 平均复购周期(天) table column/metric. |
| 下单用户数 | column:下单用户数 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品复购分析报告详情 has the 下单用户数 table column/metric. |
| 用户复购率 | column:用户复购率 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品复购分析报告详情 has the 用户复购率 table column/metric. |
| 总订单数 | column:总订单数 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品复购分析报告详情 has the 总订单数 table column/metric. |

## CRM / 合作单详情

- Route: `/crm/coopera-detail`
- Sources: auto, dialog, overlay, row-action
- Actions: 19

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 操作 | column:操作 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 合作单详情 has the 操作 table column/metric. |
| 带货订单量 | column:带货订单量 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 合作单详情 has the 带货订单量 table column/metric. |
| 带货销量 | column:带货销量 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 合作单详情 has the 带货销量 table column/metric. |
| 带货销售额 | column:带货销售额 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 合作单详情 has the 带货销售额 table column/metric. |
| 店铺 | column:店铺 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 合作单详情 has the 店铺 table column/metric. |
| 订单量 | column:订单量 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 合作单详情 has the 订单量 table column/metric. |
| 订单信息 | column:订单信息 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 合作单详情 has the 订单信息 table column/metric. |
| 合作商品 | column:合作商品 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 合作单详情 has the 合作商品 table column/metric. |
| 寄样方式 | column:寄样方式 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 合作单详情 has the 寄样方式 table column/metric. |
| 千次展示转化率 | column:千次展示转化率 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 合作单详情 has the 千次展示转化率 table column/metric. |
| 商品价格 | column:商品价格 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 合作单详情 has the 商品价格 table column/metric. |
| 商品信息 | column:商品信息 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 合作单详情 has the 商品信息 table column/metric. |
| 申样时间 | column:申样时间 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 合作单详情 has the 申样时间 table column/metric. |
| 视频播放量 | column:视频播放量 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 合作单详情 has the 视频播放量 table column/metric. |
| 视频信息 | column:视频信息 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 合作单详情 has the 视频信息 table column/metric. |
| 销量 | column:销量 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 合作单详情 has the 销量 table column/metric. |
| 销售额 | column:销售额 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 合作单详情 has the 销售额 table column/metric. |
| 样品状态 | column:样品状态 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 合作单详情 has the 样品状态 table column/metric. |
| 预估佣金 | column:预估佣金 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 合作单详情 has the 预估佣金 table column/metric. |

## CRM / 合作单详情

- Route: `/crm/cooperation-detail-simple`
- Sources: auto, dialog, overlay, row-action
- Actions: 14

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 订单列表 | selector:div#tab-order | tab | safe_execute_allowed | click_css_selector | auto | Switch 合作单详情 to the 订单列表 tab/view. |
| 视频链接 | selector:div#tab-video | tab | safe_execute_allowed | click_css_selector | auto | Switch 合作单详情 to the 视频链接 tab/view. |
| 销售数据 | selector:div#tab-sale | tab | safe_execute_allowed | click_css_selector | auto | Switch 合作单详情 to the 销售数据 tab/view. |
| 直播链接 | selector:div#tab-live | tab | safe_execute_allowed | click_css_selector | auto | Switch 合作单详情 to the 直播链接 tab/view. |
| 店铺 | column:店铺 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 合作单详情 has the 店铺 table column/metric. |
| 价格 | column:价格 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 合作单详情 has the 价格 table column/metric. |
| 结算销量 | column:结算销量 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 合作单详情 has the 结算销量 table column/metric. |
| 结算销售额 | column:结算销售额 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 合作单详情 has the 结算销售额 table column/metric. |
| 结算佣金 | column:结算佣金 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 合作单详情 has the 结算佣金 table column/metric. |
| 取消金额 | column:取消金额 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 合作单详情 has the 取消金额 table column/metric. |
| 商品信息 | column:商品信息 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 合作单详情 has the 商品信息 table column/metric. |
| 销量 | column:销量 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 合作单详情 has the 销量 table column/metric. |
| 销售额 | column:销售额 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 合作单详情 has the 销售额 table column/metric. |
| 预估佣金 | column:预估佣金 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 合作单详情 has the 预估佣金 table column/metric. |

## CRM / 合作单详情

- Route: `/crm/cooperation-detail`
- Sources: auto, dialog, overlay, row-action
- Actions: 14

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 订单列表 | selector:div#tab-order | tab | safe_execute_allowed | click_css_selector | auto | Switch 合作单详情 to the 订单列表 tab/view. |
| 视频链接 | selector:div#tab-video | tab | safe_execute_allowed | click_css_selector | auto | Switch 合作单详情 to the 视频链接 tab/view. |
| 销售数据 | selector:div#tab-sale | tab | safe_execute_allowed | click_css_selector | auto | Switch 合作单详情 to the 销售数据 tab/view. |
| 直播链接 | selector:div#tab-live | tab | safe_execute_allowed | click_css_selector | auto | Switch 合作单详情 to the 直播链接 tab/view. |
| 店铺 | column:店铺 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 合作单详情 has the 店铺 table column/metric. |
| 价格 | column:价格 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 合作单详情 has the 价格 table column/metric. |
| 结算销量 | column:结算销量 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 合作单详情 has the 结算销量 table column/metric. |
| 结算销售额 | column:结算销售额 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 合作单详情 has the 结算销售额 table column/metric. |
| 结算佣金 | column:结算佣金 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 合作单详情 has the 结算佣金 table column/metric. |
| 取消金额 | column:取消金额 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 合作单详情 has the 取消金额 table column/metric. |
| 商品信息 | column:商品信息 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 合作单详情 has the 商品信息 table column/metric. |
| 销量 | column:销量 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 合作单详情 has the 销量 table column/metric. |
| 销售额 | column:销售额 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 合作单详情 has the 销售额 table column/metric. |
| 预估佣金 | column:预估佣金 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 合作单详情 has the 预估佣金 table column/metric. |

## CRM / 收藏夹详情

- Route: `/crm/favorite/detail`
- Sources: auto, dialog, overlay, row-action
- Actions: 16

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 批量操作 | text:批量操作 | batch_action | confirmation_required_write | click_css_selector | auto | Open or run a write/configuration action on 收藏夹详情; requires explicit confirmation before committing changes. |
| 去达人广场添加 | text:去达人广场添加 | button | confirmation_required_write | click_css_selector | auto | Open or run a write/configuration action on 收藏夹详情; requires explicit confirmation before committing changes. |
| 群发邮件 | text:群发邮件 | button | confirmation_required_write | click_css_selector | auto | Open or run a write/configuration action on 收藏夹详情; requires explicit confirmation before committing changes. |
| 搜索 | text:搜索 | button | safe_execute_allowed | click_css_selector | auto | Apply or clear filters on 收藏夹详情. |
| 重置 | text:重置 | button | safe_execute_allowed | click_css_selector | auto | Apply or clear filters on 收藏夹详情. |
| 邀约次数 | text:邀约次数 | filter_dropdown | safe_execute_allowed | click_css_selector | auto | Filter 收藏夹详情 by 邀约次数. |
| 请输入昵称或达人ID | placeholder:请输入昵称或达人ID | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 收藏夹详情 by 请输入昵称或达人ID. |
| 邀约次数 | placeholder:邀约次数 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 收藏夹详情 by 邀约次数. |
| 批量操作 | overlay_trigger:批量操作 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 批量操作 overlay on 收藏夹详情. |
| 邀约次数 | overlay_trigger:邀约次数 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 邀约次数 overlay on 收藏夹详情. |
| 操作 | column:操作 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 收藏夹详情 has the 操作 table column/metric. |
| 达人信息 | column:达人信息 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 收藏夹详情 has the 达人信息 table column/metric. |
| 粉丝数 | column:粉丝数 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 收藏夹详情 has the 粉丝数 table column/metric. |
| 添加时间 | column:添加时间 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 收藏夹详情 has the 添加时间 table column/metric. |
| 邀约次数 | column:邀约次数 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 收藏夹详情 has the 邀约次数 table column/metric. |
| 总销售额 | column:总销售额 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 收藏夹详情 has the 总销售额 table column/metric. |

## CRM / 黑名单

- Route: `/crm/matser/management/blacklist`
- Sources: auto, curated, dialog, overlay, row-action, table-header
- Actions: 40

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 批量恢复 | text:批量恢复 | batch_action | confirmation_required_write | click_css_selector | auto | Open or run a write/configuration action on 黑名单; requires explicit confirmation before committing changes. |
| 批量恢复 | text:批量恢复 | button | confirmation_required_write | click_visible_dom_text | curated | Restore selected creators from blacklist. Requires selected rows and explicit confirmation. |
| 搜索 | text:搜索 | button | safe_execute_allowed | click_css_selector | auto | Apply or clear filters on 黑名单. |
| 搜索 | text:搜索 | button | safe_execute_allowed | click_visible_dom_text | curated | Apply current blacklist filters. |
| 重置 | text:重置 | button | safe_execute_allowed | click_css_selector | auto | Apply or clear filters on 黑名单. |
| 重置 | text:重置 | button | safe_execute_allowed | click_visible_dom_text | curated | Clear current blacklist filters. |
| 全部商务 | text:全部商务 | filter_dropdown | safe_execute_allowed | click_css_selector | auto | Filter 黑名单 by 全部商务. |
| 达人标签 | placeholder:达人标签 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 黑名单 by 达人标签. |
| 结束日期 | placeholder:结束日期 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 黑名单 by 结束日期. |
| 开始日期 | placeholder:开始日期 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 黑名单 by 开始日期. |
| 品类 | placeholder:品类 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 黑名单 by 品类. |
| 请输入达人ID(双击批量搜索) | placeholder:请输入达人ID(双击批量搜索) | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 黑名单 by 请输入达人ID(双击批量搜索). |
| 全部商务 | placeholder:全部商务 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 黑名单 by 全部商务. |
| 达人公海 | text:达人公海 | navigation | safe_execute_allowed | click_css_selector | auto | Navigate from 黑名单 to a related detail or analysis view. |
| 黑名单 | text:黑名单 | navigation | safe_execute_allowed | click_css_selector | auto | Navigate from 黑名单 to a related detail or analysis view. |
| 我的达人 | text:我的达人 | navigation | safe_execute_allowed | click_css_selector | auto | Navigate from 黑名单 to a related detail or analysis view. |
| 重点关注 | text:重点关注 | navigation | safe_execute_allowed | click_css_selector | auto | Navigate from 黑名单 to a related detail or analysis view. |
| 达人昵称 | 请选择 -> 达人昵称 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 达人昵称 from the 请选择 overlay on 黑名单. |
| 达人ID | 请选择 -> 达人ID | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 达人ID from the 请选择 overlay on 黑名单. |
| 今天 | 开始日期 -> 今天 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 今天 from the 开始日期 overlay on 黑名单. |
| 昨天 | 开始日期 -> 昨天 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 昨天 from the 开始日期 overlay on 黑名单. |
| 达人标签 | overlay_trigger:达人标签 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 达人标签 overlay on 黑名单. |
| 开始日期 | overlay_trigger:开始日期 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 开始日期 overlay on 黑名单. |
| 品类 | overlay_trigger:品类 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 品类 overlay on 黑名单. |
| 请选择 | overlay_trigger:请选择 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择 overlay on 黑名单. |
| 全部商务 | overlay_trigger:全部商务 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 全部商务 overlay on 黑名单. |
| 达人公海 | text:达人公海 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 黑名单 to the 达人公海 tab/view. |
| 黑名单 | text:黑名单 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 黑名单 to the 黑名单 tab/view. |
| 我的达人 | text:我的达人 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 黑名单 to the 我的达人 tab/view. |
| 重点关注 | text:重点关注 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 黑名单 to the 重点关注 tab/view. |
| 操作 | column:操作 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 黑名单 has the 操作 table column/metric. |
| 达人标签 | column:达人标签 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 黑名单 has the 达人标签 table column/metric. |
| 达人信息 | column:达人信息 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 黑名单 has the 达人信息 table column/metric. |
| 点赞数 | column:点赞数 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 黑名单 has the 点赞数 table column/metric. |
| 粉丝数 | column:粉丝数 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 黑名单 has the 粉丝数 table column/metric. |
| 拉黑操作人 | column:拉黑操作人 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 黑名单 has the 拉黑操作人 table column/metric. |
| 拉黑时间 | column:拉黑时间 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 黑名单 has the 拉黑时间 table column/metric. |
| 拉黑原因 | column:拉黑原因 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 黑名单 has the 拉黑原因 table column/metric. |
| 联系方式 | column:联系方式 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 黑名单 has the 联系方式 table column/metric. |
| 品类 | column:品类 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 黑名单 has the 品类 table column/metric. |

## CRM / 重点关注

- Route: `/crm/matser/management/focus`
- Sources: auto, curated, dialog, overlay, row-action, table-header
- Actions: 53

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 搜索 | text:搜索 | button | safe_execute_allowed | click_css_selector | auto | Apply or clear filters on 重点关注. |
| 搜索 | text:搜索 | button | safe_execute_allowed | click_visible_dom_text | curated | Apply current focus-page filters. |
| 重置 | text:重置 | button | safe_execute_allowed | click_css_selector | auto | Apply or clear filters on 重点关注. |
| 重置 | text:重置 | button | safe_execute_allowed | click_visible_dom_text | curated | Clear current focus-page filters. |
| 转移达人 | text:转移达人 | button | confirmation_required_write | click_css_selector | auto | Open or run a write/configuration action on 重点关注; requires explicit confirmation before committing changes. |
| 转移达人 | text:转移达人 | button | confirmation_required_write | click_visible_dom_text | curated | Transfer selected creators. Requires selected rows and explicit confirmation. |
| 全部商务 | text:全部商务 | filter_dropdown | safe_execute_allowed | click_css_selector | auto | Filter 重点关注 by 全部商务. |
| 状态 | text:状态 | filter_dropdown | safe_execute_allowed | click_css_selector | auto | Filter 重点关注 by 状态. |
| 结束日期 | placeholder:结束日期 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 重点关注 by 结束日期. |
| 开始日期 | placeholder:开始日期 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 重点关注 by 开始日期. |
| 品类 | placeholder:品类 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 重点关注 by 品类. |
| 请输入达人ID(双击批量搜索) | placeholder:请输入达人ID(双击批量搜索) | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 重点关注 by 请输入达人ID(双击批量搜索). |
| 全部商务 | placeholder:全部商务 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 重点关注 by 全部商务. |
| 选择标签 | placeholder:选择标签 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 重点关注 by 选择标签. |
| 状态 | placeholder:状态 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 重点关注 by 状态. |
| 达人公海 | text:达人公海 | navigation | safe_execute_allowed | click_css_selector | auto | Navigate from 重点关注 to a related detail or analysis view. |
| 黑名单 | text:黑名单 | navigation | safe_execute_allowed | click_css_selector | auto | Navigate from 重点关注 to a related detail or analysis view. |
| 我的达人 | text:我的达人 | navigation | safe_execute_allowed | click_css_selector | auto | Navigate from 重点关注 to a related detail or analysis view. |
| 重点关注 | text:重点关注 | navigation | safe_execute_allowed | click_css_selector | auto | Navigate from 重点关注 to a related detail or analysis view. |
| 达人昵称 | 请选择 -> 达人昵称 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 达人昵称 from the 请选择 overlay on 重点关注. |
| 达人ID | 请选择 -> 达人ID | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 达人ID from the 请选择 overlay on 重点关注. |
| 今天 | 开始日期 -> 今天 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 今天 from the 开始日期 overlay on 重点关注. |
| 昨天 | 开始日期 -> 昨天 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 昨天 from the 开始日期 overlay on 重点关注. |
| 开始日期 | overlay_trigger:开始日期 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 开始日期 overlay on 重点关注. |
| 品类 | overlay_trigger:品类 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 品类 overlay on 重点关注. |
| 请选择 | overlay_trigger:请选择 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择 overlay on 重点关注. |
| 全部商务 | overlay_trigger:全部商务 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 全部商务 overlay on 重点关注. |
| 选择标签 | overlay_trigger:选择标签 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 选择标签 overlay on 重点关注. |
| 状态 | overlay_trigger:状态 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 状态 overlay on 重点关注. |
| 达人公海 | text:达人公海 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 重点关注 to the 达人公海 tab/view. |
| 黑名单 | text:黑名单 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 重点关注 to the 黑名单 tab/view. |
| 我的达人 | text:我的达人 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 重点关注 to the 我的达人 tab/view. |
| 重点关注 | text:重点关注 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 重点关注 to the 重点关注 tab/view. |
| 操作 | column:操作 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 重点关注 has the 操作 table column/metric. |
| 达人标签 | column:达人标签 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 重点关注 has the 达人标签 table column/metric. |
| 达人信息 | column:达人信息 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 重点关注 has the 达人信息 table column/metric. |
| 带货订单量 | column:带货订单量 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 重点关注 has the 带货订单量 table column/metric. |
| 点赞数 | column:点赞数 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 重点关注 has the 点赞数 table column/metric. |
| 粉丝数 | column:粉丝数 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 重点关注 has the 粉丝数 table column/metric. |
| 跟进商务 | column:跟进商务 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 重点关注 has the 跟进商务 table column/metric. |
| 跟进时间 | column:跟进时间 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 重点关注 has the 跟进时间 table column/metric. |
| 互动率 | column:互动率 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 重点关注 has the 互动率 table column/metric. |
| 画像 / 品类 | column:画像 / 品类 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 重点关注 has the 画像 / 品类 table column/metric. |
| 商品销量 | column:商品销量 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 重点关注 has the 商品销量 table column/metric. |
| 视频平均播放量 | column:视频平均播放量 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 重点关注 has the 视频平均播放量 table column/metric. |
| 视频销售额 | column:视频销售额 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 重点关注 has the 视频销售额 table column/metric. |
| 销售额 | column:销售额 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 重点关注 has the 销售额 table column/metric. |
| 佣金总额 | column:佣金总额 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 重点关注 has the 佣金总额 table column/metric. |
| 直播销售额 | column:直播销售额 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 重点关注 has the 直播销售额 table column/metric. |
| 状态 | column:状态 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 重点关注 has the 状态 table column/metric. |
| GMV | column:GMV | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 重点关注 has the GMV table column/metric. |
| Item Sold | column:Item Sold | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 重点关注 has the Item Sold table column/metric. |
| ROI | column:ROI | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 重点关注 has the ROI table column/metric. |

## CRM / 达人公海

- Route: `/crm/matser/management/highSeas`
- Sources: auto, curated, dialog, overlay, row-action, table-header
- Actions: 70

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 批量操作 | text:批量操作 | batch_action | confirmation_required_write | click_css_selector | auto | Open or run a write/configuration action on 达人公海; requires explicit confirmation before committing changes. |
| 批量操作 | text:批量操作 | button_menu | confirmation_required_write | click_visible_dom_text | curated | Open batch operation menu for selected creators. Treat concrete batch action as unknown until the menu is captured. |
| 分配达人 | text:分配达人 | button | confirmation_required_write | click_css_selector | auto | Open or run a write/configuration action on 达人公海; requires explicit confirmation before committing changes. |
| 分配达人 | text:分配达人 | button | confirmation_required_write | click_visible_dom_text | curated | Assign selected creators to a business owner. Requires selected rows and explicit user confirmation. |
| 认领达人 | text:认领达人 | button | confirmation_required_write | click_css_selector | auto | Open or run a write/configuration action on 达人公海; requires explicit confirmation before committing changes. |
| 认领达人 | text:认领达人 | button | confirmation_required_write | click_visible_dom_text | curated | Claim selected creators into the current user's task/follow-up pool. Requires explicit user confirmation. |
| 搜索 | text:搜索 | button | safe_execute_allowed | click_css_selector | auto | Apply or clear filters on 达人公海. |
| 搜索 | text:搜索 | button | safe_execute_allowed | click_visible_dom_text | curated | Apply current filters and refresh the creator list. |
| 重置 | text:重置 | button | safe_execute_allowed | click_css_selector | auto | Apply or clear filters on 达人公海. |
| 重置 | text:重置 | button | safe_execute_allowed | click_visible_dom_text | curated | Clear high-seas filters and return to the default list. |
| 地区 | uia:地区 | filter_dropdown | safe_execute_allowed | uia_locator | curated | Filter creators by region. |
| 粉丝数 | uia:粉丝数 | filter_dropdown | safe_execute_allowed | uia_locator | curated | Filter creators by follower-count range. |
| 年龄分布 | text:年龄分布 | filter_dropdown | safe_execute_allowed | click_css_selector | auto | Filter 达人公海 by 年龄分布. |
| 全部商务 | text:全部商务 | filter_dropdown | safe_execute_allowed | click_css_selector | auto | Filter 达人公海 by 全部商务. |
| 全部商务 | placeholder:全部商务 | filter_dropdown | safe_execute_allowed | input_or_filter_placeholder | curated | Filter creators by business owner/follow-up owner. |
| 性别分布 | uia:性别分布 | filter_dropdown | safe_execute_allowed | uia_locator | curated | Filter creators by audience gender distribution. |
| 达人ID | placeholder:请输入达人ID(双击批量搜索) | filter_input | safe_execute_allowed | input_or_filter_placeholder | curated | Search one or multiple creator IDs. The placeholder says double-click for batch search. |
| 年龄分布 | placeholder:年龄分布 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 达人公海 by 年龄分布. |
| 年龄分布 | placeholder:年龄分布 | filter_input | safe_execute_allowed | input_or_filter_placeholder | curated | Filter creators by audience age distribution. |
| 品类 | placeholder:品类 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 达人公海 by 品类. |
| 品类 | placeholder:品类 | filter_input | safe_execute_allowed | input_or_filter_placeholder | curated | Filter creators by product/category fit. |
| 请输入达人ID(双击批量搜索) | placeholder:请输入达人ID(双击批量搜索) | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 达人公海 by 请输入达人ID(双击批量搜索). |
| 全部商务 | placeholder:全部商务 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 达人公海 by 全部商务. |
| 选择标签 | placeholder:选择标签 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 达人公海 by 选择标签. |
| 选择标签 | placeholder:选择标签 | filter_input | safe_execute_allowed | input_or_filter_placeholder | curated | Filter creators by tag. |
| 选择店铺 | placeholder:选择店铺 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 达人公海 by 选择店铺. |
| 选择店铺 | placeholder:选择店铺 | filter_input | safe_execute_allowed | input_or_filter_placeholder | curated | Filter creators by shop. |
| 达人公海 | text:达人公海 | navigation | safe_execute_allowed | click_css_selector | auto | Navigate from 达人公海 to a related detail or analysis view. |
| 黑名单 | text:黑名单 | navigation | safe_execute_allowed | click_css_selector | auto | Navigate from 达人公海 to a related detail or analysis view. |
| 我的达人 | text:我的达人 | navigation | safe_execute_allowed | click_css_selector | auto | Navigate from 达人公海 to a related detail or analysis view. |
| 重点关注 | text:重点关注 | navigation | safe_execute_allowed | click_css_selector | auto | Navigate from 达人公海 to a related detail or analysis view. |
| 达人昵称 | 请选择 -> 达人昵称 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 达人昵称 from the 请选择 overlay on 达人公海. |
| 达人ID | 请选择 -> 达人ID | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 达人ID from the 请选择 overlay on 达人公海. |
| 批量删除 | 批量操作 -> 批量删除 | overlay_item | confirmation_required_write | click_trigger_selector_then_overlay_item_text | overlay | Choose 批量删除 from the 批量操作 overlay on 达人公海. |
| 批量信息更新 | 批量操作 -> 信息更新 | overlay_item | confirmation_required_write | click_trigger_selector_then_overlay_item_text | overlay | Choose 信息更新 from the 批量操作 overlay on 达人公海. |
| 年龄分布 | overlay_trigger:年龄分布 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 年龄分布 overlay on 达人公海. |
| 批量操作 | overlay_trigger:批量操作 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 批量操作 overlay on 达人公海. |
| 品类 | overlay_trigger:品类 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 品类 overlay on 达人公海. |
| 请选择 | overlay_trigger:请选择 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择 overlay on 达人公海. |
| 全部商务 | overlay_trigger:全部商务 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 全部商务 overlay on 达人公海. |
| 选择标签 | overlay_trigger:选择标签 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 选择标签 overlay on 达人公海. |
| 选择店铺 | overlay_trigger:选择店铺 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 选择店铺 overlay on 达人公海. |
| 操作分配 | 操作 -> 分配 | row_action | confirmation_required_write | click_first_matching_row_action_in_table | row-action | Use row action 分配 in the 操作 column on 达人公海. |
| 操作认领 | 操作 -> 认领 | row_action | confirmation_required_write | click_first_matching_row_action_in_table | row-action | Use row action 认领 in the 操作 column on 达人公海. |
| 操作删除 | 操作 -> 删除 | row_action | confirmation_required_write | click_first_matching_row_action_in_table | row-action | Use row action 删除 in the 操作 column on 达人公海. |
| 操作详情 | 操作 -> 详情 | row_action | safe_execute_allowed | click_first_matching_row_action_in_table | row-action | Use row action 详情 in the 操作 column on 达人公海. |
| 达人公海 | text:达人公海 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 达人公海 to the 达人公海 tab/view. |
| 合作中 | status_tab:合作中 | status_tab | safe_execute_allowed | click_visible_action_text | curated | Show creators currently cooperating. |
| 黑名单 | text:黑名单 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 达人公海 to the 黑名单 tab/view. |
| 全部 | status_tab:全部 | status_tab | safe_execute_allowed | click_visible_action_text | curated | Show all creators in the high-seas list. |
| 我的达人 | text:我的达人 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 达人公海 to the 我的达人 tab/view. |
| 已出单 | status_tab:已出单 | status_tab | safe_execute_allowed | click_visible_action_text | curated | Show creators that already generated orders. |
| 已触达 | status_tab:已触达 | status_tab | safe_execute_allowed | click_visible_action_text | curated | Show creators already reached/contacted. |
| 已申样 | status_tab:已申样 | status_tab | safe_execute_allowed | click_visible_action_text | curated | Show creators already in sample request status. |
| 重点关注 | text:重点关注 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 达人公海 to the 重点关注 tab/view. |
| 合作中 | selector:div#tab-2 | tab | safe_execute_allowed | click_css_selector | auto | Switch 达人公海 to the 合作中 tab/view. |
| 全部 | selector:div#tab-0 | tab | safe_execute_allowed | click_css_selector | auto | Switch 达人公海 to the 全部 tab/view. |
| 已出单 | selector:div#tab-3 | tab | safe_execute_allowed | click_css_selector | auto | Switch 达人公海 to the 已出单 tab/view. |
| 已触达 | selector:div#tab-1 | tab | safe_execute_allowed | click_css_selector | auto | Switch 达人公海 to the 已触达 tab/view. |
| 已申样 | selector:div#tab-4 | tab | safe_execute_allowed | click_css_selector | auto | Switch 达人公海 to the 已申样 tab/view. |
| 操作 | column:操作 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 达人公海 has the 操作 table column/metric. |
| 达人标签 | column:达人标签 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 达人公海 has the 达人标签 table column/metric. |
| 达人信息 | column:达人信息 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 达人公海 has the 达人信息 table column/metric. |
| 粉丝数 | column:粉丝数 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 达人公海 has the 粉丝数 table column/metric. |
| 跟进商务 | column:跟进商务 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 达人公海 has the 跟进商务 table column/metric. |
| 画像 / 品类 | column:画像 / 品类 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 达人公海 has the 画像 / 品类 table column/metric. |
| 交互时间 | column:交互时间 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 达人公海 has the 交互时间 table column/metric. |
| 状态 | column:状态 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 达人公海 has the 状态 table column/metric. |
| GMV | column:GMV | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 达人公海 has the GMV table column/metric. |
| Item Sold | column:Item Sold | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 达人公海 has the Item Sold table column/metric. |

## CRM / 我的达人

- Route: `/crm/matser/management/myMaster`
- Sources: auto, curated, dialog, overlay, row-action, table-header
- Actions: 59

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 批量操作 | text:批量操作 | batch_action | confirmation_required_write | click_css_selector | auto | Open or run a write/configuration action on 我的达人; requires explicit confirmation before committing changes. |
| 批量操作 | text:批量操作 | button_menu | confirmation_required_write | click_visible_dom_text | curated | Open batch operation menu. Concrete menu items still need capture after opening the menu. |
| 搜索 | text:搜索 | button | safe_execute_allowed | click_css_selector | auto | Apply or clear filters on 我的达人. |
| 搜索 | text:搜索 | button | safe_execute_allowed | click_visible_dom_text | curated | Apply current my-master filters. |
| 添加达人 | text:添加达人 | button | confirmation_required_write | click_css_selector | auto | Open or run a write/configuration action on 我的达人; requires explicit confirmation before committing changes. |
| 添加达人 | text:添加达人 | button | confirmation_required_write | click_visible_dom_text | curated | Open add-creator flow. Requires explicit confirmation before submitting any data. |
| 重置 | text:重置 | button | safe_execute_allowed | click_css_selector | auto | Apply or clear filters on 我的达人. |
| 重置 | text:重置 | button | safe_execute_allowed | click_visible_dom_text | curated | Clear current my-master filters. |
| 添加达人关闭 | 添加达人 -> 关闭 | dialog_button | safe_execute_allowed | click_trigger_selector_then_dialog_button_text | dialog | Use 关闭 inside the 添加达人 dialog/drawer on 我的达人. |
| 添加达人取消 | 添加达人 -> 取消 | dialog_button | safe_execute_allowed | click_trigger_selector_then_dialog_button_text | dialog | Use 取消 inside the 添加达人 dialog/drawer on 我的达人. |
| 添加达人确定 | 添加达人 -> 确定 | dialog_button | confirmation_required_write | click_trigger_selector_then_dialog_button_text | dialog | Use 确定 inside the 添加达人 dialog/drawer on 我的达人. |
| 添加达人搜索 | 添加达人 -> 搜索 | dialog_button | safe_execute_allowed | click_trigger_selector_then_dialog_button_text | dialog | Use 搜索 inside the 添加达人 dialog/drawer on 我的达人. |
| 添加达人添加 | 添加达人 -> 添加 | dialog_button | confirmation_required_write | click_trigger_selector_then_dialog_button_text | dialog | Use 添加 inside the 添加达人 dialog/drawer on 我的达人. |
| 添加达人 | dialog_opener:添加达人 | dialog_opener | safe_execute_allowed | click_trigger_selector | dialog | Open the 添加达人 dialog/drawer on 我的达人; do not submit changes without explicit confirmation. |
| 年龄分布 | text:年龄分布 | filter_dropdown | safe_execute_allowed | click_css_selector | auto | Filter 我的达人 by 年龄分布. |
| 全部商务 | text:全部商务 | filter_dropdown | safe_execute_allowed | click_css_selector | auto | Filter 我的达人 by 全部商务. |
| 结束日期 | placeholder:结束日期 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 我的达人 by 结束日期. |
| 开始日期 | placeholder:开始日期 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 我的达人 by 开始日期. |
| 年龄分布 | placeholder:年龄分布 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 我的达人 by 年龄分布. |
| 品类 | placeholder:品类 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 我的达人 by 品类. |
| 请输入达人ID(双击批量搜索) | placeholder:请输入达人ID(双击批量搜索) | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 我的达人 by 请输入达人ID(双击批量搜索). |
| 全部商务 | placeholder:全部商务 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 我的达人 by 全部商务. |
| 选择标签 | placeholder:选择标签 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 我的达人 by 选择标签. |
| 达人公海 | text:达人公海 | navigation | safe_execute_allowed | click_css_selector | auto | Navigate from 我的达人 to a related detail or analysis view. |
| 黑名单 | text:黑名单 | navigation | safe_execute_allowed | click_css_selector | auto | Navigate from 我的达人 to a related detail or analysis view. |
| 我的达人 | text:我的达人 | navigation | safe_execute_allowed | click_css_selector | auto | Navigate from 我的达人 to a related detail or analysis view. |
| 重点关注 | text:重点关注 | navigation | safe_execute_allowed | click_css_selector | auto | Navigate from 我的达人 to a related detail or analysis view. |
| 达人昵称 | 请选择 -> 达人昵称 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 达人昵称 from the 请选择 overlay on 我的达人. |
| 达人ID | 请选择 -> 达人ID | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 达人ID from the 请选择 overlay on 我的达人. |
| 今天 | 开始日期 -> 今天 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 今天 from the 开始日期 overlay on 我的达人. |
| 批量信息更新 | 批量操作 -> 信息更新 | overlay_item | confirmation_required_write | click_trigger_selector_then_overlay_item_text | overlay | Choose 信息更新 from the 批量操作 overlay on 我的达人. |
| 批量转移达人 | 批量操作 -> 转移达人 | overlay_item | confirmation_required_write | click_trigger_selector_then_overlay_item_text | overlay | Choose 转移达人 from the 批量操作 overlay on 我的达人. |
| 昨天 | 开始日期 -> 昨天 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 昨天 from the 开始日期 overlay on 我的达人. |
| 开始日期 | overlay_trigger:开始日期 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 开始日期 overlay on 我的达人. |
| 年龄分布 | overlay_trigger:年龄分布 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 年龄分布 overlay on 我的达人. |
| 批量操作 | overlay_trigger:批量操作 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 批量操作 overlay on 我的达人. |
| 品类 | overlay_trigger:品类 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 品类 overlay on 我的达人. |
| 请选择 | overlay_trigger:请选择 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择 overlay on 我的达人. |
| 全部商务 | overlay_trigger:全部商务 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 全部商务 overlay on 我的达人. |
| 选择标签 | overlay_trigger:选择标签 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 选择标签 overlay on 我的达人. |
| 达人公海 | text:达人公海 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 我的达人 to the 达人公海 tab/view. |
| 黑名单 | text:黑名单 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 我的达人 to the 黑名单 tab/view. |
| 我的达人 | text:我的达人 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 我的达人 to the 我的达人 tab/view. |
| 重点关注 | text:重点关注 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 我的达人 to the 重点关注 tab/view. |
| 合作中 | selector:div#tab-2 | tab | safe_execute_allowed | click_css_selector | auto | Switch 我的达人 to the 合作中 tab/view. |
| 全部 | selector:div#tab-0 | tab | safe_execute_allowed | click_css_selector | auto | Switch 我的达人 to the 全部 tab/view. |
| 已出单 | selector:div#tab-3 | tab | safe_execute_allowed | click_css_selector | auto | Switch 我的达人 to the 已出单 tab/view. |
| 已触达 | selector:div#tab-1 | tab | safe_execute_allowed | click_css_selector | auto | Switch 我的达人 to the 已触达 tab/view. |
| 已申样 | selector:div#tab-4 | tab | safe_execute_allowed | click_css_selector | auto | Switch 我的达人 to the 已申样 tab/view. |
| 操作 | column:操作 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 我的达人 has the 操作 table column/metric. |
| 达人标签 | column:达人标签 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 我的达人 has the 达人标签 table column/metric. |
| 达人信息 | column:达人信息 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 我的达人 has the 达人信息 table column/metric. |
| 粉丝数 | column:粉丝数 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 我的达人 has the 粉丝数 table column/metric. |
| 跟进商务 | column:跟进商务 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 我的达人 has the 跟进商务 table column/metric. |
| 跟进时间 | column:跟进时间 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 我的达人 has the 跟进时间 table column/metric. |
| 画像 / 品类 | column:画像 / 品类 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 我的达人 has the 画像 / 品类 table column/metric. |
| 状态 | column:状态 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 我的达人 has the 状态 table column/metric. |
| GMV | column:GMV | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 我的达人 has the GMV table column/metric. |
| Item Sold | column:Item Sold | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 我的达人 has the Item Sold table column/metric. |

## CRM / 店铺详情

- Route: `/crm/shop-detail`
- Sources: auto, dialog, overlay, row-action
- Actions: 7

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 店铺商品 | selector:div#tab-goods | tab | safe_execute_allowed | click_css_selector | auto | Switch 店铺详情 to the 店铺商品 tab/view. |
| 关联达人 | selector:div#tab-master | tab | safe_execute_allowed | click_css_selector | auto | Switch 店铺详情 to the 关联达人 tab/view. |
| 单价 | column:单价 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺详情 has the 单价 table column/metric. |
| 关联达人 | column:关联达人 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺详情 has the 关联达人 table column/metric. |
| 商品信息 | column:商品信息 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺详情 has the 商品信息 table column/metric. |
| 总销量 | column:总销量 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺详情 has the 总销量 table column/metric. |
| 总销售额 | column:总销售额 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺详情 has the 总销售额 table column/metric. |

## CRM / 数据概览

- Route: `/dataView/data-overview`
- Sources: auto, curated, dialog, overlay, row-action, table-header
- Actions: 27

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 搜索 | text:搜索 | button | safe_execute_allowed | click_css_selector | auto | Apply or clear filters on 数据概览. |
| 搜索 | text:搜索 | button | safe_execute_allowed | click_visible_dom_text | curated | Apply current data-overview filters. |
| 重置 | text:重置 | button | safe_execute_allowed | click_css_selector | auto | Apply or clear filters on 数据概览. |
| 重置 | text:重置 | button | safe_execute_allowed | click_visible_dom_text | curated | Clear current data-overview filters. |
| 全部商务 | text:全部商务 | filter_dropdown | safe_execute_allowed | click_css_selector | auto | Filter 数据概览 by 全部商务. |
| 搜索商品名称或链接ID | text:搜索商品名称或链接ID | filter_dropdown | safe_execute_allowed | click_css_selector | auto | Filter 数据概览 by 搜索商品名称或链接ID. |
| 结束日期 | placeholder:结束日期 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 数据概览 by 结束日期. |
| 开始日期 | placeholder:开始日期 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 数据概览 by 开始日期. |
| 全部商务 | placeholder:全部商务 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 数据概览 by 全部商务. |
| 搜索商品名称或链接ID | placeholder:搜索商品名称或链接ID | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 数据概览 by 搜索商品名称或链接ID. |
| 选择店铺 | placeholder:选择店铺 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 数据概览 by 选择店铺. |
| 今天 | 开始日期 -> 今天 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 今天 from the 开始日期 overlay on 数据概览. |
| 昨天 | 开始日期 -> 昨天 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 昨天 from the 开始日期 overlay on 数据概览. |
| 开始日期 | overlay_trigger:开始日期 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 开始日期 overlay on 数据概览. |
| 请选择 | overlay_trigger:请选择 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择 overlay on 数据概览. |
| 全部商务 | overlay_trigger:全部商务 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 全部商务 overlay on 数据概览. |
| 搜索商品名称或链接ID | overlay_trigger:搜索商品名称或链接ID | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 搜索商品名称或链接ID overlay on 数据概览. |
| 选择店铺 | overlay_trigger:选择店铺 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 选择店铺 overlay on 数据概览. |
| 近30天 | selector:div#tab-2 | tab | safe_execute_allowed | click_css_selector | auto | Switch 数据概览 to the 近30天 tab/view. |
| 近7天 | selector:div#tab-1 | tab | safe_execute_allowed | click_css_selector | auto | Switch 数据概览 to the 近7天 tab/view. |
| 昨天 | selector:div#tab-0 | tab | safe_execute_allowed | click_css_selector | auto | Switch 数据概览 to the 昨天 tab/view. |
| 成交订单量 | column:成交订单量 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 数据概览 has the 成交订单量 table column/metric. |
| 成交金额 | column:成交金额 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 数据概览 has the 成交金额 table column/metric. |
| 成交商品数 | column:成交商品数 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 数据概览 has the 成交商品数 table column/metric. |
| 达人信息 | column:达人信息 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 数据概览 has the 达人信息 table column/metric. |
| 店铺 | column:店铺 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 数据概览 has the 店铺 table column/metric. |
| 排名 | column:排名 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 数据概览 has the 排名 table column/metric. |

## ERP / 流程定义

- Route: `/bpm/manager/definition`
- Sources: auto, dialog, overlay, row-action
- Actions: 9

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 表单信息 | column:表单信息 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 流程定义 has the 表单信息 table column/metric. |
| 部署时间 | column:部署时间 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 流程定义 has the 部署时间 table column/metric. |
| 操作 | column:操作 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 流程定义 has the 操作 table column/metric. |
| 定义编号 | column:定义编号 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 流程定义 has the 定义编号 table column/metric. |
| 定义分类 | column:定义分类 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 流程定义 has the 定义分类 table column/metric. |
| 定义描述 | column:定义描述 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 流程定义 has the 定义描述 table column/metric. |
| 定义名称 | column:定义名称 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 流程定义 has the 定义名称 table column/metric. |
| 流程版本 | column:流程版本 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 流程定义 has the 流程版本 table column/metric. |
| 状态 | column:状态 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 流程定义 has the 状态 table column/metric. |

## ERP / 发起 OA 请假

- Route: `/bpm/oa/leave/create`
- Sources: auto, dialog, overlay, row-action
- Actions: 7

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 提 交 | text:提 交 | button | confirmation_required_write | click_css_selector | auto | Open or run a write/configuration action on 发起 OA 请假; requires explicit confirmation before committing changes. |
| 请输入原因 | placeholder:请输入原因 | form_input | safe_execute_allowed | click_css_selector | auto | Fill or choose the 请输入原因 field on 发起 OA 请假; submitting the form still requires explicit confirmation. |
| 选择结束时间 | placeholder:选择结束时间 | form_input | safe_execute_allowed | click_css_selector | auto | Fill or choose the 选择结束时间 field on 发起 OA 请假; submitting the form still requires explicit confirmation. |
| 选择开始时间 | placeholder:选择开始时间 | form_input | safe_execute_allowed | click_css_selector | auto | Fill or choose the 选择开始时间 field on 发起 OA 请假; submitting the form still requires explicit confirmation. |
| 请选择 | overlay_trigger:请选择 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择 overlay on 发起 OA 请假. |
| 选择结束时间 | overlay_trigger:选择结束时间 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 选择结束时间 overlay on 发起 OA 请假. |
| 选择开始时间 | overlay_trigger:选择开始时间 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 选择开始时间 overlay on 发起 OA 请假. |

## ERP / 查看 OA 请假

- Route: `/bpm/oa/leave/detail`
- Sources: auto, dialog, overlay, row-action
- Actions: 4

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 保存配置 | text:保存配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 查看 OA 请假; requires explicit confirmation before committing changes. |
| 用户菜单 | text:用户菜单 | button | safe_execute_allowed | click_visible_dom_text | auto | Open the current user/account menu. |
| 重置配置 | text:重置配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 查看 OA 请假; requires explicit confirmation before committing changes. |
| 首页 | text:首页 | navigation | safe_execute_allowed | navigate_href | auto | Navigate from 查看 OA 请假 to a related detail or analysis view. |

## ERP / 发起流程

- Route: `/bpm/process-instance/create`
- Sources: auto, dialog, overlay, row-action
- Actions: 5

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 操作 | column:操作 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 发起流程 has the 操作 table column/metric. |
| 流程版本 | column:流程版本 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 发起流程 has the 流程版本 table column/metric. |
| 流程分类 | column:流程分类 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 发起流程 has the 流程分类 table column/metric. |
| 流程描述 | column:流程描述 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 发起流程 has the 流程描述 table column/metric. |
| 流程名称 | column:流程名称 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 发起流程 has the 流程名称 table column/metric. |

## ERP / 流程详情

- Route: `/bpm/process-instance/detail`
- Sources: auto, dialog, overlay, row-action
- Actions: 4

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 保存配置 | text:保存配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 流程详情; requires explicit confirmation before committing changes. |
| 用户菜单 | text:用户菜单 | button | safe_execute_allowed | click_visible_dom_text | auto | Open the current user/account menu. |
| 重置配置 | text:重置配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 流程详情; requires explicit confirmation before committing changes. |
| 首页 | text:首页 | navigation | safe_execute_allowed | navigate_href | auto | Navigate from 流程详情 to a related detail or analysis view. |

## ERP / 黑名单管理

- Route: `/erp/blacklist`
- Sources: auto, dialog, overlay, row-action
- Actions: 13

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 批量删除 | text:批量删除 | batch_action | confirmation_required_write | click_css_selector | auto | Open or run a write/configuration action on 黑名单管理; requires explicit confirmation before committing changes. |
| 新增 | text:新增 | button | confirmation_required_write | click_css_selector | auto | Open or run a write/configuration action on 黑名单管理; requires explicit confirmation before committing changes. |
| 重置 | text:重置 | button | safe_execute_allowed | click_css_selector | auto | Apply or clear filters on 黑名单管理. |
| 自动加黑 | text:自动加黑 | button | confirmation_required_write | click_css_selector | auto | Open or run a write/configuration action on 黑名单管理; requires explicit confirmation before committing changes. |
| 新增关闭 | 新增 -> 关闭 | dialog_button | safe_execute_allowed | click_trigger_selector_then_dialog_button_text | dialog | Use 关闭 inside the 新增 dialog/drawer on 黑名单管理. |
| 新增取消 | 新增 -> 取消 | dialog_button | safe_execute_allowed | click_trigger_selector_then_dialog_button_text | dialog | Use 取消 inside the 新增 dialog/drawer on 黑名单管理. |
| 新增确定 | 新增 -> 确定 | dialog_button | confirmation_required_write | click_trigger_selector_then_dialog_button_text | dialog | Use 确定 inside the 新增 dialog/drawer on 黑名单管理. |
| 新增 | dialog_opener:新增 | dialog_opener | safe_execute_allowed | click_trigger_selector | dialog | Open the 新增 dialog/drawer on 黑名单管理; do not submit changes without explicit confirmation. |
| 请输入买家地址 | placeholder:请输入买家地址 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 黑名单管理 by 请输入买家地址. |
| 操作 | column:操作 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 黑名单管理 has the 操作 table column/metric. |
| 创建时间 | column:创建时间 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 黑名单管理 has the 创建时间 table column/metric. |
| 买家地址 | column:买家地址 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 黑名单管理 has the 买家地址 table column/metric. |
| 原因 | column:原因 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 黑名单管理 has the 原因 table column/metric. |

## ERP / 调度日志

- Route: `/job/log`
- Sources: auto, dialog, overlay, row-action
- Actions: 21

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 搜索 | text:搜索 | button | safe_execute_allowed | click_css_selector | auto | Apply or clear filters on 调度日志. |
| 重置 | text:重置 | button | safe_execute_allowed | click_css_selector | auto | Apply or clear filters on 调度日志. |
| 请选择任务状态 | text:请选择任务状态 | filter_dropdown | safe_execute_allowed | click_css_selector | auto | Filter 调度日志 by 请选择任务状态. |
| 请输入处理器的名字 | placeholder:请输入处理器的名字 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 调度日志 by 请输入处理器的名字. |
| 请选择任务状态 | placeholder:请选择任务状态 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 调度日志 by 请选择任务状态. |
| 选择结束执行时间 | placeholder:选择结束执行时间 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 调度日志 by 选择结束执行时间. |
| 选择开始执行时间 | placeholder:选择开始执行时间 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 调度日志 by 选择开始执行时间. |
| 成功 | 请选择任务状态 -> 成功 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 成功 from the 请选择任务状态 overlay on 调度日志. |
| 失败 | 请选择任务状态 -> 失败 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 失败 from the 请选择任务状态 overlay on 调度日志. |
| 请选择任务状态 | overlay_trigger:请选择任务状态 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择任务状态 overlay on 调度日志. |
| 选择结束执行时间 | overlay_trigger:选择结束执行时间 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 选择结束执行时间 overlay on 调度日志. |
| 选择开始执行时间 | overlay_trigger:选择开始执行时间 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 选择开始执行时间 overlay on 调度日志. |
| 操作 | column:操作 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 调度日志 has the 操作 table column/metric. |
| 处理器的参数 | column:处理器的参数 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 调度日志 has the 处理器的参数 table column/metric. |
| 处理器的名字 | column:处理器的名字 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 调度日志 has the 处理器的名字 table column/metric. |
| 第几次执行 | column:第几次执行 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 调度日志 has the 第几次执行 table column/metric. |
| 任务编号 | column:任务编号 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 调度日志 has the 任务编号 table column/metric. |
| 任务状态 | column:任务状态 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 调度日志 has the 任务状态 table column/metric. |
| 日志编号 | column:日志编号 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 调度日志 has the 日志编号 table column/metric. |
| 执行时间 | column:执行时间 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 调度日志 has the 执行时间 table column/metric. |
| 执行时长 | column:执行时长 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 调度日志 has the 执行时长 table column/metric. |

## ERP / 预警消息

- Route: `/monitor/message_list`
- Sources: auto, dialog, overlay, row-action
- Actions: 35

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 标记未处理 | text:标记未处理 | button | confirmation_required_write | click_css_selector | auto | Open or run a write/configuration action on 预警消息; requires explicit confirmation before committing changes. |
| 标记已处理 | text:标记已处理 | button | confirmation_required_write | click_css_selector | auto | Open or run a write/configuration action on 预警消息; requires explicit confirmation before committing changes. |
| 重置 | text:重置 | button | safe_execute_allowed | click_css_selector | auto | Apply or clear filters on 预警消息. |
| 结束日期 | placeholder:结束日期 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 预警消息 by 结束日期. |
| 开始日期 | placeholder:开始日期 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 预警消息 by 开始日期. |
| 请输入规则名称 | placeholder:请输入规则名称 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 预警消息 by 请输入规则名称. |
| 选择店铺 | placeholder:选择店铺 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 预警消息 by 选择店铺. |
| 店铺健康 | text:店铺健康 | navigation | safe_execute_allowed | click_css_selector | auto | Navigate from 预警消息 to a related detail or analysis view. |
| 售价监控 | text:售价监控 | navigation | safe_execute_allowed | click_css_selector | auto | Navigate from 预警消息 to a related detail or analysis view. |
| 物流监控 | text:物流监控 | navigation | safe_execute_allowed | click_css_selector | auto | Navigate from 预警消息 to a related detail or analysis view. |
| 预警规则 | text:预警规则 | navigation | safe_execute_allowed | click_css_selector | auto | Navigate from 预警消息 to a related detail or analysis view. |
| 预警消息 | text:预警消息 | navigation | safe_execute_allowed | click_css_selector | auto | Navigate from 预警消息 to a related detail or analysis view. |
| 按店铺 | 请选择 -> 按店铺 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 按店铺 from the 请选择 overlay on 预警消息. |
| 按人员 | 请选择 -> 按人员 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 按人员 from the 请选择 overlay on 预警消息. |
| 今天 | 开始日期 -> 今天 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 今天 from the 开始日期 overlay on 预警消息. |
| 昨天 | 开始日期 -> 昨天 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 昨天 from the 开始日期 overlay on 预警消息. |
| 开始日期 | overlay_trigger:开始日期 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 开始日期 overlay on 预警消息. |
| 请选择 | overlay_trigger:请选择 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择 overlay on 预警消息. |
| 选择店铺 | overlay_trigger:选择店铺 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 选择店铺 overlay on 预警消息. |
| 店铺 | text:店铺 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 预警消息 to the 店铺 tab/view. |
| 店铺健康 | text:店铺健康 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 预警消息 to the 店铺健康 tab/view. |
| 订单 | text:订单 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 预警消息 to the 订单 tab/view. |
| 商品 | text:商品 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 预警消息 to the 商品 tab/view. |
| 售价监控 | text:售价监控 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 预警消息 to the 售价监控 tab/view. |
| 物流监控 | text:物流监控 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 预警消息 to the 物流监控 tab/view. |
| 预警规则 | text:预警规则 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 预警消息 to the 预警规则 tab/view. |
| 预警消息 | text:预警消息 | status_tab | safe_execute_allowed | click_css_selector | auto | Switch 预警消息 to the 预警消息 tab/view. |
| 操作 | column:操作 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 预警消息 has the 操作 table column/metric. |
| 处理状态 | column:处理状态 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 预警消息 has the 处理状态 table column/metric. |
| 订单信息 | column:订单信息 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 预警消息 has the 订单信息 table column/metric. |
| 规则名称 | column:规则名称 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 预警消息 has the 规则名称 table column/metric. |
| 预警类型 | column:预警类型 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 预警消息 has the 预警类型 table column/metric. |
| 预警内容 | column:预警内容 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 预警消息 has the 预警内容 table column/metric. |
| 预警时间 | column:预警时间 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 预警消息 has the 预警时间 table column/metric. |
| 预警条件 | column:预警条件 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 预警消息 has the 预警条件 table column/metric. |

## ERP / SKU最低售价配置

- Route: `/order/sku-min-price`
- Sources: auto, dialog, overlay, row-action
- Actions: 19

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 批量删除 | text:批量删除 | batch_action | confirmation_required_write | click_css_selector | auto | Open or run a write/configuration action on SKU最低售价配置; requires explicit confirmation before committing changes. |
| 导入导出 | text:导入导出 | button | confirmation_required_export | click_css_selector | auto | Export or download data from SKU最低售价配置; requires an explicit user request. |
| 搜索 | text:搜索 | button | safe_execute_allowed | click_css_selector | auto | Apply or clear filters on SKU最低售价配置. |
| 新增 | text:新增 | button | confirmation_required_write | click_css_selector | auto | Open or run a write/configuration action on SKU最低售价配置; requires explicit confirmation before committing changes. |
| 重置 | text:重置 | button | safe_execute_allowed | click_css_selector | auto | Apply or clear filters on SKU最低售价配置. |
| 新增关闭 | 新增 -> 关闭 | dialog_button | safe_execute_allowed | click_trigger_selector_then_dialog_button_text | dialog | Use 关闭 inside the 新增 dialog/drawer on SKU最低售价配置. |
| 新增取消 | 新增 -> 取消 | dialog_button | safe_execute_allowed | click_trigger_selector_then_dialog_button_text | dialog | Use 取消 inside the 新增 dialog/drawer on SKU最低售价配置. |
| 新增确定 | 新增 -> 确定 | dialog_button | confirmation_required_write | click_trigger_selector_then_dialog_button_text | dialog | Use 确定 inside the 新增 dialog/drawer on SKU最低售价配置. |
| 新增选择 | 新增 -> 选择 | dialog_button | safe_execute_allowed | click_trigger_selector_then_dialog_button_text | dialog | Use 选择 inside the 新增 dialog/drawer on SKU最低售价配置. |
| 新增 | dialog_opener:新增 | dialog_opener | safe_execute_allowed | click_trigger_selector | dialog | Open the 新增 dialog/drawer on SKU最低售价配置; do not submit changes without explicit confirmation. |
| 请输入商品SKU | placeholder:请输入商品SKU | filter_input | safe_execute_allowed | click_css_selector | auto | Filter SKU最低售价配置 by 请输入商品SKU. |
| 选择店铺 | placeholder:选择店铺 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter SKU最低售价配置 by 选择店铺. |
| 导出最低售价 | 导入导出 -> 导出最低售价 | overlay_item | confirmation_required_export | click_trigger_selector_then_overlay_item_text | overlay | Choose 导出最低售价 from the 导入导出 overlay on SKU最低售价配置. |
| 导入导出 | overlay_trigger:导入导出 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 导入导出 overlay on SKU最低售价配置. |
| 选择店铺 | overlay_trigger:选择店铺 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 选择店铺 overlay on SKU最低售价配置. |
| 操作 | column:操作 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that SKU最低售价配置 has the 操作 table column/metric. |
| 店铺 | column:店铺 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that SKU最低售价配置 has the 店铺 table column/metric. |
| 商品SKU | column:商品SKU | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that SKU最低售价配置 has the 商品SKU table column/metric. |
| 最低售价 | column:最低售价 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that SKU最低售价配置 has the 最低售价 table column/metric. |

## ERP / 商品评论详情

- Route: `/product-data/detail`
- Sources: auto, dialog, overlay, row-action
- Actions: 19

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 同步评论 | text:同步评论 | button | confirmation_required_write | click_css_selector | auto | Open or run a write/configuration action on 商品评论详情; requires explicit confirmation before committing changes. |
| 重置 | text:重置 | button | safe_execute_allowed | click_css_selector | auto | Apply or clear filters on 商品评论详情. |
| 结束日期 | placeholder:结束日期 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 商品评论详情 by 结束日期. |
| 开始日期 | placeholder:开始日期 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 商品评论详情 by 开始日期. |
| 请输入平台订单号 | placeholder:请输入平台订单号 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 商品评论详情 by 请输入平台订单号. |
| 今天 | 开始日期 -> 今天 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 今天 from the 开始日期 overlay on 商品评论详情. |
| 未处理 | 请选择 -> 未处理 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 未处理 from the 请选择 overlay on 商品评论详情. |
| 已处理 | 请选择 -> 已处理 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 已处理 from the 请选择 overlay on 商品评论详情. |
| 昨天 | 开始日期 -> 昨天 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 昨天 from the 开始日期 overlay on 商品评论详情. |
| 开始日期 | overlay_trigger:开始日期 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 开始日期 overlay on 商品评论详情. |
| 请选择 | overlay_trigger:请选择 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择 overlay on 商品评论详情. |
| 今天 | selector:div#tab-0 | tab | safe_execute_allowed | click_css_selector | auto | Switch 商品评论详情 to the 今天 tab/view. |
| 近30天 | selector:div#tab-3 | tab | safe_execute_allowed | click_css_selector | auto | Switch 商品评论详情 to the 近30天 tab/view. |
| 近7天 | selector:div#tab-2 | tab | safe_execute_allowed | click_css_selector | auto | Switch 商品评论详情 to the 近7天 tab/view. |
| 昨天 | selector:div#tab-1 | tab | safe_execute_allowed | click_css_selector | auto | Switch 商品评论详情 to the 昨天 tab/view. |
| 操作 | column:操作 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品评论详情 has the 操作 table column/metric. |
| 处理状态 | column:处理状态 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品评论详情 has the 处理状态 table column/metric. |
| 评级 | column:评级 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品评论详情 has the 评级 table column/metric. |
| 评价信息 翻译 | column:评价信息 翻译 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品评论详情 has the 评价信息 翻译 table column/metric. |

## ERP / 商品表现分析

- Route: `/product-data/performance-detail`
- Sources: auto, dialog, overlay, row-action
- Actions: 48

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 点击量 | column:点击量 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品表现分析 has the 点击量 table column/metric. |
| 点击率 | column:点击率 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品表现分析 has the 点击率 table column/metric. |
| 点赞量 | column:点赞量 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品表现分析 has the 点赞量 table column/metric. |
| 访客数 | column:访客数 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品表现分析 has the 访客数 table column/metric. |
| 广告订单量 | column:广告订单量 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品表现分析 has the 广告订单量 table column/metric. |
| 广告花费 | column:广告花费 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品表现分析 has the 广告花费 table column/metric. |
| 广告数据 | column:广告数据 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品表现分析 has the 广告数据 table column/metric. |
| 广告销量 | column:广告销量 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品表现分析 has the 广告销量 table column/metric. |
| 广告销售额 | column:广告销售额 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品表现分析 has the 广告销售额 table column/metric. |
| 加购访客数 | column:加购访客数 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品表现分析 has the 加购访客数 table column/metric. |
| 加购商品数 | column:加购商品数 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品表现分析 has the 加购商品数 table column/metric. |
| 加购转化率 | column:加购转化率 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品表现分析 has the 加购转化率 table column/metric. |
| 每次直接转化成本 | column:每次直接转化成本 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品表现分析 has the 每次直接转化成本 table column/metric. |
| 每次转化成本 | column:每次转化成本 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品表现分析 has the 每次转化成本 table column/metric. |
| 日期 | column:日期 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品表现分析 has the 日期 table column/metric. |
| 商品访问数据 | column:商品访问数据 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品表现分析 has the 商品访问数据 table column/metric. |
| 商品加购数据 | column:商品加购数据 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品表现分析 has the 商品加购数据 table column/metric. |
| 商品收藏数 | column:商品收藏数 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品表现分析 has the 商品收藏数 table column/metric. |
| 退款订单量 | column:退款订单量 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品表现分析 has the 退款订单量 table column/metric. |
| 退款率 | column:退款率 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品表现分析 has the 退款率 table column/metric. |
| 下单到已确定订单转化率 | column:下单到已确定订单转化率 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品表现分析 has the 下单到已确定订单转化率 table column/metric. |
| 下单金额 | column:下单金额 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品表现分析 has the 下单金额 table column/metric. |
| 下单买家数 | column:下单买家数 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品表现分析 has the 下单买家数 table column/metric. |
| 下单商品数 | column:下单商品数 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品表现分析 has the 下单商品数 table column/metric. |
| 下单数据 | column:下单数据 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品表现分析 has the 下单数据 table column/metric. |
| 下单转化率 | column:下单转化率 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品表现分析 has the 下单转化率 table column/metric. |
| 销售数据 | column:销售数据 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品表现分析 has the 销售数据 table column/metric. |
| 已确定订单买家数 | column:已确定订单买家数 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品表现分析 has the 已确定订单买家数 table column/metric. |
| 已确定订单数据 | column:已确定订单数据 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品表现分析 has the 已确定订单数据 table column/metric. |
| 已确定订单销售额 | column:已确定订单销售额 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品表现分析 has the 已确定订单销售额 table column/metric. |
| 已确定订单销售量 | column:已确定订单销售量 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品表现分析 has the 已确定订单销售量 table column/metric. |
| 已确定订单转化率 | column:已确定订单转化率 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品表现分析 has the 已确定订单转化率 table column/metric. |
| 有效订单量 | column:有效订单量 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品表现分析 has the 有效订单量 table column/metric. |
| 有效销量 | column:有效销量 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品表现分析 has the 有效销量 table column/metric. |
| 有效销售额 | column:有效销售额 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品表现分析 has the 有效销售额 table column/metric. |
| 展现量 | column:展现量 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品表现分析 has the 展现量 table column/metric. |
| 直接销售额 | column:直接销售额 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品表现分析 has the 直接销售额 table column/metric. |
| 直接已售商品 | column:直接已售商品 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品表现分析 has the 直接已售商品 table column/metric. |
| 直接转化 | column:直接转化 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品表现分析 has the 直接转化 table column/metric. |
| 直接转化率 | column:直接转化率 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品表现分析 has the 直接转化率 table column/metric. |
| 直接CIR | column:直接CIR | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品表现分析 has the 直接CIR table column/metric. |
| 直接ROAS | column:直接ROAS | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品表现分析 has the 直接ROAS table column/metric. |
| 转化率 | column:转化率 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品表现分析 has the 转化率 table column/metric. |
| ACoAS | column:ACoAS | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品表现分析 has the ACoAS table column/metric. |
| ASoAS | column:ASoAS | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品表现分析 has the ASoAS table column/metric. |
| CIR | column:CIR | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品表现分析 has the CIR table column/metric. |
| PV | column:PV | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品表现分析 has the PV table column/metric. |
| ROAS | column:ROAS | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 商品表现分析 has the ROAS table column/metric. |

## ERP / 进销存详情

- Route: `/product-sku/InventoryReport_detail`
- Sources: auto, dialog, overlay, row-action
- Actions: 26

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 搜索 | text:搜索 | button | safe_execute_allowed | click_css_selector | auto | Apply or clear filters on 进销存详情. |
| 重置 | text:重置 | button | safe_execute_allowed | click_css_selector | auto | Apply or clear filters on 进销存详情. |
| 结束日期 | placeholder:结束日期 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 进销存详情 by 结束日期. |
| 开始日期 | placeholder:开始日期 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 进销存详情 by 开始日期. |
| 今天 | 开始日期 -> 今天 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 今天 from the 开始日期 overlay on 进销存详情. |
| 昨天 | 开始日期 -> 昨天 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 昨天 from the 开始日期 overlay on 进销存详情. |
| 开始日期 | overlay_trigger:开始日期 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 开始日期 overlay on 进销存详情. |
| 请选择 | overlay_trigger:请选择 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择 overlay on 进销存详情. |
| 近30天 | selector:div#tab-30 | tab | safe_execute_allowed | click_css_selector | auto | Switch 进销存详情 to the 近30天 tab/view. |
| 近7天 | selector:div#tab-7 | tab | safe_execute_allowed | click_css_selector | auto | Switch 进销存详情 to the 近7天 tab/view. |
| 昨天 | selector:div#tab-1 | tab | safe_execute_allowed | click_css_selector | auto | Switch 进销存详情 to the 昨天 tab/view. |
| 采购入库 | column:采购入库 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 进销存详情 has the 采购入库 table column/metric. |
| 出库 | column:出库 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 进销存详情 has the 出库 table column/metric. |
| 调拨出库 | column:调拨出库 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 进销存详情 has the 调拨出库 table column/metric. |
| 调拨入库 | column:调拨入库 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 进销存详情 has the 调拨入库 table column/metric. |
| 盘亏出库 | column:盘亏出库 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 进销存详情 has the 盘亏出库 table column/metric. |
| 盘盈入库 | column:盘盈入库 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 进销存详情 has the 盘盈入库 table column/metric. |
| 取消单入库 | column:取消单入库 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 进销存详情 has the 取消单入库 table column/metric. |
| 日期 | column:日期 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 进销存详情 has the 日期 table column/metric. |
| 入库 | column:入库 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 进销存详情 has the 入库 table column/metric. |
| 三方仓同步出库 | column:三方仓同步出库 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 进销存详情 has the 三方仓同步出库 table column/metric. |
| 三方仓同步入库 | column:三方仓同步入库 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 进销存详情 has the 三方仓同步入库 table column/metric. |
| 手动出库 | column:手动出库 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 进销存详情 has the 手动出库 table column/metric. |
| 手动入库 | column:手动入库 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 进销存详情 has the 手动入库 table column/metric. |
| 退货入库 | column:退货入库 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 进销存详情 has the 退货入库 table column/metric. |
| 销售出库 | column:销售出库 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 进销存详情 has the 销售出库 table column/metric. |

## ERP / 业绩利润报表

- Route: `/report-center/detail/performance`
- Sources: auto, dialog, overlay, row-action
- Actions: 10

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 导出报表 | text:导出报表 | button | confirmation_required_export | click_css_selector | auto | Export or download data from 业绩利润报表; requires an explicit user request. |
| 重置 | text:重置 | button | safe_execute_allowed | click_css_selector | auto | Apply or clear filters on 业绩利润报表. |
| 请选择运营人员 | text:请选择运营人员 | filter_dropdown | safe_execute_allowed | click_css_selector | auto | Filter 业绩利润报表 by 请选择运营人员. |
| 请选择运营人员 | placeholder:请选择运营人员 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 业绩利润报表 by 请选择运营人员. |
| 选择日期 | placeholder:选择日期 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 业绩利润报表 by 选择日期. |
| 按回款时间 | 请选择 -> 按回款时间 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 按回款时间 from the 请选择 overlay on 业绩利润报表. |
| 按下单时间 | 请选择 -> 按下单时间 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 按下单时间 from the 请选择 overlay on 业绩利润报表. |
| 请选择 | overlay_trigger:请选择 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择 overlay on 业绩利润报表. |
| 请选择运营人员 | overlay_trigger:请选择运营人员 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择运营人员 overlay on 业绩利润报表. |
| 选择日期 | overlay_trigger:选择日期 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 选择日期 overlay on 业绩利润报表. |

## ERP / 店铺利润报表

- Route: `/report-center/detail/shop`
- Sources: auto, dialog, overlay, row-action
- Actions: 9

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 导出报表 | text:导出报表 | button | confirmation_required_export | click_css_selector | auto | Export or download data from 店铺利润报表; requires an explicit user request. |
| 重置 | text:重置 | button | safe_execute_allowed | click_css_selector | auto | Apply or clear filters on 店铺利润报表. |
| 选择店铺 | placeholder:选择店铺 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 店铺利润报表 by 选择店铺. |
| 选择日期 | placeholder:选择日期 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 店铺利润报表 by 选择日期. |
| 按回款时间 | 请选择 -> 按回款时间 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 按回款时间 from the 请选择 overlay on 店铺利润报表. |
| 按下单时间 | 请选择 -> 按下单时间 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 按下单时间 from the 请选择 overlay on 店铺利润报表. |
| 请选择 | overlay_trigger:请选择 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择 overlay on 店铺利润报表. |
| 选择店铺 | overlay_trigger:选择店铺 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 选择店铺 overlay on 店铺利润报表. |
| 选择日期 | overlay_trigger:选择日期 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 选择日期 overlay on 店铺利润报表. |

## ERP / Shopee商品数据表

- Route: `/report-center/detail/shopeeGoods`
- Sources: auto, dialog, overlay, row-action
- Actions: 48

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 导出报表 | text:导出报表 | button | confirmation_required_export | click_css_selector | auto | Export or download data from Shopee商品数据表; requires an explicit user request. |
| 重置 | text:重置 | button | safe_execute_allowed | click_css_selector | auto | Apply or clear filters on Shopee商品数据表. |
| 结束日期 | placeholder:结束日期 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter Shopee商品数据表 by 结束日期. |
| 开始日期 | placeholder:开始日期 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter Shopee商品数据表 by 开始日期. |
| 请选择商品 | placeholder:请选择商品 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter Shopee商品数据表 by 请选择商品. |
| 今天 | 开始日期 -> 今天 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 今天 from the 开始日期 overlay on Shopee商品数据表. |
| 昨天 | 开始日期 -> 昨天 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 昨天 from the 开始日期 overlay on Shopee商品数据表. |
| 开始日期 | overlay_trigger:开始日期 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 开始日期 overlay on Shopee商品数据表. |
| 测评金额 | column:测评金额 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee商品数据表 has the 测评金额 table column/metric. |
| 测评损耗 | column:测评损耗 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee商品数据表 has the 测评损耗 table column/metric. |
| 测评销量 | column:测评销量 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee商品数据表 has the 测评销量 table column/metric. |
| 产出 | column:产出 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee商品数据表 has the 产出 table column/metric. |
| 关联广告点击率 | column:关联广告点击率 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee商品数据表 has the 关联广告点击率 table column/metric. |
| 关联广告费 | column:关联广告费 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee商品数据表 has the 关联广告费 table column/metric. |
| 关联广告销售额 | column:关联广告销售额 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee商品数据表 has the 关联广告销售额 table column/metric. |
| 关联广告转化 | column:关联广告转化 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee商品数据表 has the 关联广告转化 table column/metric. |
| 关联广告转化率 | column:关联广告转化率 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee商品数据表 has the 关联广告转化率 table column/metric. |
| 关联广告ROI | column:关联广告ROI | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee商品数据表 has the 关联广告ROI table column/metric. |
| 件数 | column:件数 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee商品数据表 has the 件数 table column/metric. |
| 利润 | column:利润 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee商品数据表 has the 利润 table column/metric. |
| 平均客单价 | column:平均客单价 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee商品数据表 has the 平均客单价 table column/metric. |
| 平台费用 | column:平台费用 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee商品数据表 has the 平台费用 table column/metric. |
| 日期 | column:日期 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee商品数据表 has the 日期 table column/metric. |
| 商品成本 | column:商品成本 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee商品数据表 has the 商品成本 table column/metric. |
| 商品访客数 | column:商品访客数 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee商品数据表 has the 商品访客数 table column/metric. |
| 收入 | column:收入 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee商品数据表 has the 收入 table column/metric. |
| 搜索广告点击率 | column:搜索广告点击率 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee商品数据表 has the 搜索广告点击率 table column/metric. |
| 搜索广告费 | column:搜索广告费 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee商品数据表 has the 搜索广告费 table column/metric. |
| 搜索广告销售额 | column:搜索广告销售额 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee商品数据表 has the 搜索广告销售额 table column/metric. |
| 搜索广告转化 | column:搜索广告转化 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee商品数据表 has the 搜索广告转化 table column/metric. |
| 搜索广告转化率 | column:搜索广告转化率 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee商品数据表 has the 搜索广告转化率 table column/metric. |
| 搜索广告ROI | column:搜索广告ROI | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee商品数据表 has the 搜索广告ROI table column/metric. |
| 推广广告点击率 | column:推广广告点击率 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee商品数据表 has the 推广广告点击率 table column/metric. |
| 推广广告费 | column:推广广告费 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee商品数据表 has the 推广广告费 table column/metric. |
| 推广广告销售额 | column:推广广告销售额 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee商品数据表 has the 推广广告销售额 table column/metric. |
| 推广广告转化 | column:推广广告转化 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee商品数据表 has the 推广广告转化 table column/metric. |
| 推广广告转化率 | column:推广广告转化率 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee商品数据表 has the 推广广告转化率 table column/metric. |
| 推广广告ROI | column:推广广告ROI | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee商品数据表 has the 推广广告ROI table column/metric. |
| 退款金额 | column:退款金额 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee商品数据表 has the 退款金额 table column/metric. |
| 项目 | column:项目 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee商品数据表 has the 项目 table column/metric. |
| 销售 | column:销售 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee商品数据表 has the 销售 table column/metric. |
| 销售利润率 | column:销售利润率 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee商品数据表 has the 销售利润率 table column/metric. |
| 有效销量 | column:有效销量 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee商品数据表 has the 有效销量 table column/metric. |
| 有效销售额 | column:有效销售额 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee商品数据表 has the 有效销售额 table column/metric. |
| 预估运费 | column:预估运费 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee商品数据表 has the 预估运费 table column/metric. |
| 支出 | column:支出 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee商品数据表 has the 支出 table column/metric. |
| 转化率 | column:转化率 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee商品数据表 has the 转化率 table column/metric. |
| 总数据 | column:总数据 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee商品数据表 has the 总数据 table column/metric. |

## ERP / Shopee店铺数据表

- Route: `/report-center/detail/shopeeShop`
- Sources: auto, dialog, overlay, row-action
- Actions: 52

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 导出报表 | text:导出报表 | button | confirmation_required_export | click_css_selector | auto | Export or download data from Shopee店铺数据表; requires an explicit user request. |
| 重置 | text:重置 | button | safe_execute_allowed | click_css_selector | auto | Apply or clear filters on Shopee店铺数据表. |
| 结束日期 | placeholder:结束日期 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter Shopee店铺数据表 by 结束日期. |
| 开始日期 | placeholder:开始日期 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter Shopee店铺数据表 by 开始日期. |
| 选择店铺 | placeholder:选择店铺 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter Shopee店铺数据表 by 选择店铺. |
| 今天 | 开始日期 -> 今天 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 今天 from the 开始日期 overlay on Shopee店铺数据表. |
| 昨天 | 开始日期 -> 昨天 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 昨天 from the 开始日期 overlay on Shopee店铺数据表. |
| 开始日期 | overlay_trigger:开始日期 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 开始日期 overlay on Shopee店铺数据表. |
| 请选择 | overlay_trigger:请选择 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择 overlay on Shopee店铺数据表. |
| 选择店铺 | overlay_trigger:选择店铺 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 选择店铺 overlay on Shopee店铺数据表. |
| 测评订单量 | column:测评订单量 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee店铺数据表 has the 测评订单量 table column/metric. |
| 测评金额 | column:测评金额 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee店铺数据表 has the 测评金额 table column/metric. |
| 测评损耗 | column:测评损耗 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee店铺数据表 has the 测评损耗 table column/metric. |
| 测评销量 | column:测评销量 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee店铺数据表 has the 测评销量 table column/metric. |
| 产出 | column:产出 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee店铺数据表 has the 产出 table column/metric. |
| 店铺转化率 | column:店铺转化率 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee店铺数据表 has the 店铺转化率 table column/metric. |
| 订单量 | column:订单量 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee店铺数据表 has the 订单量 table column/metric. |
| 访客数 | column:访客数 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee店铺数据表 has the 访客数 table column/metric. |
| 关联广告点击率 | column:关联广告点击率 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee店铺数据表 has the 关联广告点击率 table column/metric. |
| 关联广告费 | column:关联广告费 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee店铺数据表 has the 关联广告费 table column/metric. |
| 关联广告销售额 | column:关联广告销售额 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee店铺数据表 has the 关联广告销售额 table column/metric. |
| 关联广告转化 | column:关联广告转化 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee店铺数据表 has the 关联广告转化 table column/metric. |
| 关联广告转化率 | column:关联广告转化率 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee店铺数据表 has the 关联广告转化率 table column/metric. |
| 关联广告ROI | column:关联广告ROI | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee店铺数据表 has the 关联广告ROI table column/metric. |
| 利润 | column:利润 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee店铺数据表 has the 利润 table column/metric. |
| 每个订单的销售额 | column:每个订单的销售额 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee店铺数据表 has the 每个订单的销售额 table column/metric. |
| 平台费用 | column:平台费用 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee店铺数据表 has the 平台费用 table column/metric. |
| 日期 | column:日期 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee店铺数据表 has the 日期 table column/metric. |
| 商品成本 | column:商品成本 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee店铺数据表 has the 商品成本 table column/metric. |
| 收入 | column:收入 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee店铺数据表 has the 收入 table column/metric. |
| 搜索广告点击率 | column:搜索广告点击率 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee店铺数据表 has the 搜索广告点击率 table column/metric. |
| 搜索广告费 | column:搜索广告费 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee店铺数据表 has the 搜索广告费 table column/metric. |
| 搜索广告销售额 | column:搜索广告销售额 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee店铺数据表 has the 搜索广告销售额 table column/metric. |
| 搜索广告转化 | column:搜索广告转化 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee店铺数据表 has the 搜索广告转化 table column/metric. |
| 搜索广告转化率 | column:搜索广告转化率 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee店铺数据表 has the 搜索广告转化率 table column/metric. |
| 搜索广告ROI | column:搜索广告ROI | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee店铺数据表 has the 搜索广告ROI table column/metric. |
| 推广广告点击率 | column:推广广告点击率 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee店铺数据表 has the 推广广告点击率 table column/metric. |
| 推广广告费 | column:推广广告费 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee店铺数据表 has the 推广广告费 table column/metric. |
| 推广广告销售额 | column:推广广告销售额 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee店铺数据表 has the 推广广告销售额 table column/metric. |
| 推广广告转化 | column:推广广告转化 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee店铺数据表 has the 推广广告转化 table column/metric. |
| 推广广告转化率 | column:推广广告转化率 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee店铺数据表 has the 推广广告转化率 table column/metric. |
| 推广广告ROI | column:推广广告ROI | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee店铺数据表 has the 推广广告ROI table column/metric. |
| 退款金额 | column:退款金额 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee店铺数据表 has the 退款金额 table column/metric. |
| 项目 | column:项目 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee店铺数据表 has the 项目 table column/metric. |
| 销售额 | column:销售额 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee店铺数据表 has the 销售额 table column/metric. |
| 销售利润率 | column:销售利润率 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee店铺数据表 has the 销售利润率 table column/metric. |
| 有效订单量 | column:有效订单量 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee店铺数据表 has the 有效订单量 table column/metric. |
| 有效销量 | column:有效销量 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee店铺数据表 has the 有效销量 table column/metric. |
| 有效销售额 | column:有效销售额 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee店铺数据表 has the 有效销售额 table column/metric. |
| 预估运费 | column:预估运费 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee店铺数据表 has the 预估运费 table column/metric. |
| 支出 | column:支出 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee店铺数据表 has the 支出 table column/metric. |
| 总数据 | column:总数据 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that Shopee店铺数据表 has the 总数据 table column/metric. |

## ERP / 店铺表现看板

- Route: `/shop-data/performance-board`
- Sources: auto, dialog, overlay, row-action
- Actions: 1

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 查看操作教程 | text:查看操作教程 | navigation | safe_execute_allowed | click_css_selector | auto | Navigate from 店铺表现看板 to a related detail or analysis view. |

## ERP / 店铺表现分析

- Route: `/shop-data/performance-detail`
- Sources: auto, dialog, overlay, row-action
- Actions: 45

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 点击量 | column:点击量 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺表现分析 has the 点击量 table column/metric. |
| 点击率 | column:点击率 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺表现分析 has the 点击率 table column/metric. |
| 点赞量 | column:点赞量 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺表现分析 has the 点赞量 table column/metric. |
| 访客数 | column:访客数 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺表现分析 has the 访客数 table column/metric. |
| 广告订单量 | column:广告订单量 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺表现分析 has the 广告订单量 table column/metric. |
| 广告花费 | column:广告花费 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺表现分析 has the 广告花费 table column/metric. |
| 广告数据 | column:广告数据 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺表现分析 has the 广告数据 table column/metric. |
| 广告销量 | column:广告销量 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺表现分析 has the 广告销量 table column/metric. |
| 广告销售额 | column:广告销售额 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺表现分析 has the 广告销售额 table column/metric. |
| 加购访客数 | column:加购访客数 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺表现分析 has the 加购访客数 table column/metric. |
| 加购商品数 | column:加购商品数 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺表现分析 has the 加购商品数 table column/metric. |
| 加购转化率 | column:加购转化率 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺表现分析 has the 加购转化率 table column/metric. |
| 每次直接转化成本 | column:每次直接转化成本 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺表现分析 has the 每次直接转化成本 table column/metric. |
| 每次转化成本 | column:每次转化成本 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺表现分析 has the 每次转化成本 table column/metric. |
| 日期 | column:日期 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺表现分析 has the 日期 table column/metric. |
| 商品表现 | column:商品表现 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺表现分析 has the 商品表现 table column/metric. |
| 商品收藏数 | column:商品收藏数 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺表现分析 has the 商品收藏数 table column/metric. |
| 退款订单量 | column:退款订单量 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺表现分析 has the 退款订单量 table column/metric. |
| 退款率 | column:退款率 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺表现分析 has the 退款率 table column/metric. |
| 下单到已确定订单转化率 | column:下单到已确定订单转化率 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺表现分析 has the 下单到已确定订单转化率 table column/metric. |
| 下单金额 | column:下单金额 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺表现分析 has the 下单金额 table column/metric. |
| 下单买家数 | column:下单买家数 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺表现分析 has the 下单买家数 table column/metric. |
| 下单商品数 | column:下单商品数 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺表现分析 has the 下单商品数 table column/metric. |
| 下单转化率 | column:下单转化率 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺表现分析 has the 下单转化率 table column/metric. |
| 销售数据 | column:销售数据 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺表现分析 has the 销售数据 table column/metric. |
| 已确定订单买家数 | column:已确定订单买家数 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺表现分析 has the 已确定订单买家数 table column/metric. |
| 已确定订单销售额 | column:已确定订单销售额 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺表现分析 has the 已确定订单销售额 table column/metric. |
| 已确定订单销售量 | column:已确定订单销售量 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺表现分析 has the 已确定订单销售量 table column/metric. |
| 已确定订单转化率 | column:已确定订单转化率 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺表现分析 has the 已确定订单转化率 table column/metric. |
| 有效订单量 | column:有效订单量 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺表现分析 has the 有效订单量 table column/metric. |
| 有效销量 | column:有效销量 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺表现分析 has the 有效销量 table column/metric. |
| 有效销售额 | column:有效销售额 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺表现分析 has the 有效销售额 table column/metric. |
| 展现量 | column:展现量 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺表现分析 has the 展现量 table column/metric. |
| 直接销售额 | column:直接销售额 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺表现分析 has the 直接销售额 table column/metric. |
| 直接已售商品 | column:直接已售商品 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺表现分析 has the 直接已售商品 table column/metric. |
| 直接转化 | column:直接转化 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺表现分析 has the 直接转化 table column/metric. |
| 直接转化率 | column:直接转化率 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺表现分析 has the 直接转化率 table column/metric. |
| 直接CIR | column:直接CIR | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺表现分析 has the 直接CIR table column/metric. |
| 直接ROAS | column:直接ROAS | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺表现分析 has the 直接ROAS table column/metric. |
| 转化率 | column:转化率 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺表现分析 has the 转化率 table column/metric. |
| ACoAS | column:ACoAS | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺表现分析 has the ACoAS table column/metric. |
| ASoAS | column:ASoAS | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺表现分析 has the ASoAS table column/metric. |
| CIR | column:CIR | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺表现分析 has the CIR table column/metric. |
| PV | column:PV | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺表现分析 has the PV table column/metric. |
| ROAS | column:ROAS | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 店铺表现分析 has the ROAS table column/metric. |

## ERP / 授权失败

- Route: `/shop/auth-fail`
- Sources: auto, dialog, overlay, row-action
- Actions: 1

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 返回 | text:返回 | button | safe_execute_allowed | click_css_selector | auto | Navigate from 授权失败 to a related detail or analysis view. |

## ERP / 授权结果

- Route: `/shop/auth`
- Sources: auto, dialog, overlay, row-action
- Actions: 1

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 返回 | text:返回 | button | safe_execute_allowed | click_css_selector | auto | Navigate from 授权结果 to a related detail or analysis view. |

## ERP / 自定义费用

- Route: `/system/costom-fee`
- Sources: auto, dialog, overlay, row-action
- Actions: 26

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 批量导入自定义费用 | text:批量导入自定义费用 | batch_action | confirmation_required_write | click_css_selector | auto | Open or run a write/configuration action on 自定义费用; requires explicit confirmation before committing changes. |
| 批量删除 | text:批量删除 | batch_action | confirmation_required_write | click_css_selector | auto | Open or run a write/configuration action on 自定义费用; requires explicit confirmation before committing changes. |
| 编辑 | text:编辑 | button | confirmation_required_write | click_css_selector | auto | Open or run a write/configuration action on 自定义费用; requires explicit confirmation before committing changes. |
| 删除 | text:删除 | button | confirmation_required_write | click_css_selector | auto | Open or run a write/configuration action on 自定义费用; requires explicit confirmation before committing changes. |
| 搜索 | text:搜索 | button | safe_execute_allowed | click_css_selector | auto | Apply or clear filters on 自定义费用. |
| 新增自定义费用 | text:新增自定义费用 | button | confirmation_required_write | click_css_selector | auto | Open or run a write/configuration action on 自定义费用; requires explicit confirmation before committing changes. |
| 重置 | text:重置 | button | safe_execute_allowed | click_css_selector | auto | Apply or clear filters on 自定义费用. |
| 编辑取消 | 编辑 -> 取消 | dialog_button | safe_execute_allowed | row_context_required_dialog | dialog | Remember 取消 inside the row-level 编辑 dialog/drawer on 自定义费用; execution requires an explicit target row. |
| 编辑确定 | 编辑 -> 确定 | dialog_button | confirmation_required_write | row_context_required_dialog | dialog | Remember 确定 inside the row-level 编辑 dialog/drawer on 自定义费用; execution requires an explicit target row. |
| 新增自定义费用取消 | 新增自定义费用 -> 取消 | dialog_button | safe_execute_allowed | click_trigger_selector_then_dialog_button_text | dialog | Use 取消 inside the 新增自定义费用 dialog/drawer on 自定义费用. |
| 新增自定义费用确定 | 新增自定义费用 -> 确定 | dialog_button | confirmation_required_write | click_trigger_selector_then_dialog_button_text | dialog | Use 确定 inside the 新增自定义费用 dialog/drawer on 自定义费用. |
| 编辑 | 编辑 | dialog_opener | safe_execute_allowed | row_context_required_dialog | dialog | Remember the row-level 编辑 dialog/drawer on 自定义费用; execution requires an explicit target row. |
| 新增自定义费用 | dialog_opener:新增自定义费用 | dialog_opener | safe_execute_allowed | click_trigger_selector | dialog | Open the 新增自定义费用 dialog/drawer on 自定义费用; do not submit changes without explicit confirmation. |
| 选择店铺 | placeholder:选择店铺 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 自定义费用 by 选择店铺. |
| 选择月 | placeholder:选择月 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 自定义费用 by 选择月. |
| 请选择 | overlay_trigger:请选择 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择 overlay on 自定义费用. |
| 选择店铺 | overlay_trigger:选择店铺 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 选择店铺 overlay on 自定义费用. |
| 选择月 | overlay_trigger:选择月 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 选择月 overlay on 自定义费用. |
| 操作编辑 | 操作 -> 编辑 | row_action | confirmation_required_write | click_first_matching_row_action_in_table | row-action | Use row action 编辑 in the 操作 column on 自定义费用. |
| 操作删除 | 操作 -> 删除 | row_action | confirmation_required_write | click_first_matching_row_action_in_table | row-action | Use row action 删除 in the 操作 column on 自定义费用. |
| 操作 | column:操作 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 自定义费用 has the 操作 table column/metric. |
| 创建时间 | column:创建时间 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 自定义费用 has the 创建时间 table column/metric. |
| 店铺 | column:店铺 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 自定义费用 has the 店铺 table column/metric. |
| 费用类型 | column:费用类型 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 自定义费用 has the 费用类型 table column/metric. |
| 费用月份 | column:费用月份 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 自定义费用 has the 费用月份 table column/metric. |
| 金额 | column:金额 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 自定义费用 has the 金额 table column/metric. |

## ERP / 套餐开通记录

- Route: `/system/package-open-record`
- Sources: auto, dialog, overlay, row-action
- Actions: 10

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 重置 | text:重置 | button | safe_execute_allowed | click_css_selector | auto | Apply or clear filters on 套餐开通记录. |
| 结束日期 | placeholder:结束日期 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 套餐开通记录 by 结束日期. |
| 开始日期 | placeholder:开始日期 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 套餐开通记录 by 开始日期. |
| 租户名称/联系人/手机号 | placeholder:租户名称/联系人/手机号 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 套餐开通记录 by 租户名称/联系人/手机号. |
| 开始日期 | overlay_trigger:开始日期 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 开始日期 overlay on 套餐开通记录. |
| 请选择 | overlay_trigger:请选择 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择 overlay on 套餐开通记录. |
| 开通人 | column:开通人 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 套餐开通记录 has the 开通人 table column/metric. |
| 开通时间 | column:开通时间 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 套餐开通记录 has the 开通时间 table column/metric. |
| 套餐 | column:套餐 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 套餐开通记录 has the 套餐 table column/metric. |
| 租户 | column:租户 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 套餐开通记录 has the 租户 table column/metric. |

## ERP / 单量套餐

- Route: `/user/package`
- Sources: auto, dialog, overlay, row-action
- Actions: 1

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 单量套餐 | selector:div#tab-order | tab | safe_execute_allowed | click_css_selector | auto | Switch 单量套餐 to the 单量套餐 tab/view. |

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
- Sources: auto, curated, dialog, overlay, row-action, table-header
- Actions: 19

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 重置 | text:重置 | button | safe_execute_allowed | click_css_selector | auto | Apply or clear filters on 下载中心. |
| 重置 | text:重置 | button | safe_execute_allowed | click_visible_dom_text | curated | Clear current download-center filters. |
| 日期范围 | placeholders:开始日期/结束日期 | date_filter | safe_execute_allowed | input_or_filter_placeholder_list | curated | Filter download-center reports by date range. |
| 报告名称 | column:报表名称 | filter_input | safe_execute_allowed | input_or_filter_placeholder | curated | Search generated reports by report name. |
| 结束日期 | placeholder:结束日期 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 下载中心 by 结束日期. |
| 开始日期 | placeholder:开始日期 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 下载中心 by 开始日期. |
| 请输入报告名称 | placeholder:请输入报告名称 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 下载中心 by 请输入报告名称. |
| 今天 | 开始日期 -> 今天 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 今天 from the 开始日期 overlay on 下载中心. |
| 昨天 | 开始日期 -> 昨天 | overlay_item | safe_execute_allowed | click_trigger_selector_then_overlay_item_text | overlay | Choose 昨天 from the 开始日期 overlay on 下载中心. |
| 开始日期 | overlay_trigger:开始日期 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 开始日期 overlay on 下载中心. |
| 请选择 | overlay_trigger:请选择 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择 overlay on 下载中心. |
| 操作 | column:操作 | row_operation | confirmation_required_export | row_context_required_column_header | curated | Operate on a generated report row, usually to download or open the generated file. Exact row button text still needs capture. |
| 报表名称 | column:报表名称 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 下载中心 has the 报表名称 table column/metric. |
| 报表日期范围 | column:报表日期范围 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 下载中心 has the 报表日期范围 table column/metric. |
| 操作 | column:操作 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 下载中心 has the 操作 table column/metric. |
| 创建时间 | column:创建时间 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 下载中心 has the 创建时间 table column/metric. |
| 功能模块 | column:功能模块 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 下载中心 has the 功能模块 table column/metric. |
| 生成时间 | column:生成时间 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 下载中心 has the 生成时间 table column/metric. |
| 生成状态 | column:生成状态 | table_column | safe_execute_allowed | read_table_column_header | table-header | Remember that 下载中心 has the 生成状态 table column/metric. |

## System / 首页

- Route: `/index/home`
- Sources: auto, dialog, overlay, row-action
- Actions: 17

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 切换币种 | text:切换币种 | button | safe_execute_allowed | click_css_selector | auto | Change the visible view setting on 首页. |
| 结束日期 | placeholder:结束日期 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 首页 by 结束日期. |
| 开始日期 | placeholder:开始日期 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 首页 by 开始日期. |
| 选择店铺 | placeholder:选择店铺 | filter_input | safe_execute_allowed | click_css_selector | auto | Filter 首页 by 选择店铺. |
| 开始日期 | overlay_trigger:开始日期 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 开始日期 overlay on 首页. |
| 请选择 | overlay_trigger:请选择 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 请选择 overlay on 首页. |
| 选择店铺 | overlay_trigger:选择店铺 | overlay_trigger | safe_execute_allowed | click_trigger_selector | overlay | Open the 选择店铺 overlay on 首页. |
| 城市 | column:城市 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 首页 has the 城市 table column/metric. |
| 店铺 | column:店铺 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 首页 has the 店铺 table column/metric. |
| 分析 | column:分析 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 首页 has the 分析 table column/metric. |
| 利润(CNY) | column:利润(CNY) | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 首页 has the 利润(CNY) table column/metric. |
| 利润率 | column:利润率 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 首页 has the 利润率 table column/metric. |
| 排名 | column:排名 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 首页 has the 排名 table column/metric. |
| 有效订单量 | column:有效订单量 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 首页 has the 有效订单量 table column/metric. |
| 有效订单量占比 | column:有效订单量占比 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 首页 has the 有效订单量占比 table column/metric. |
| 有效销量 | column:有效销量 | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 首页 has the 有效销量 table column/metric. |
| 有效销售额(CNY) | column:有效销售额(CNY) | table_column | safe_execute_allowed | read_table_column_header | auto | Remember that 首页 has the 有效销售额(CNY) table column/metric. |

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
- Sources: auto, dialog, overlay, row-action
- Actions: 4

| Action | Context | Type | Safety | Strategy | Source | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| 保存配置 | text:保存配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 套餐; requires explicit confirmation before committing changes. |
| 用户菜单 | text:用户菜单 | button | safe_execute_allowed | click_visible_dom_text | auto | Open the current user/account menu. |
| 重置配置 | text:重置配置 | button | confirmation_required_write | click_visible_dom_text | auto | Open or run a write/configuration action on 套餐; requires explicit confirmation before committing changes. |
| 首页 | text:首页 | navigation | safe_execute_allowed | navigate_href | auto | Navigate from 套餐 to a related detail or analysis view. |
