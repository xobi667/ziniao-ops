[CmdletBinding(PositionalBinding = $false)]
param(
  [switch]$Json
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$queryScript = Join-Path $PSScriptRoot "query-xinjian-ui-action.ps1"
$invokeScript = Join-Path $PSScriptRoot "invoke-xinjian-ui-action.ps1"

function U([int[]]$Codepoints) {
  return -join ($Codepoints | ForEach-Object { [char]$_ })
}

$textOpenDownloadCenter = (U @(0x6253, 0x5F00, 0x4E0B, 0x8F7D, 0x4E2D, 0x5FC3))
$textDownloadCenter = (U @(0x4E0B, 0x8F7D, 0x4E2D, 0x5FC3))
$textOpenShopSelector = (U @(0x6253, 0x5F00, 0x9009, 0x62E9, 0x5E97, 0x94FA))
$textShopSelector = (U @(0x9009, 0x62E9, 0x5E97, 0x94FA))
$textViewShopColumn = (U @(0x67E5, 0x770B, 0x5E97, 0x94FA, 0x5217))
$textShop = (U @(0x5E97, 0x94FA))
$textRecent7Days = ((U @(0x8FD1)) + "7" + (U @(0x5929)))
$textAdSpend = (U @(0x5E7F, 0x544A, 0x82B1, 0x8D39))
$textExportRuleLog = (U @(0x5BFC, 0x51FA, 0x5E7F, 0x544A, 0x89C4, 0x5219, 0x65E5, 0x5FD7))
$textSearchCreatorId = ((U @(0x641C, 0x7D22, 0x8FBE, 0x4EBA)) + "ID")
$textSwitchCurrency = (U @(0x5207, 0x6362, 0x5E01, 0x79CD))

function Add-Failure {
  param(
    [System.Collections.Generic.List[object]]$Failures,
    [string]$Message
  )
  [void]$Failures.Add($Message)
}

function Test-ExpectedValue {
  param(
    [System.Collections.Generic.List[object]]$Failures,
    [string]$Label,
    [object]$Actual,
    [object]$Expected
  )
  if ($null -eq $Expected -or [string]$Expected -eq "") { return }
  if ([string]$Actual -ne [string]$Expected) {
    Add-Failure -Failures $Failures -Message ("{0}: expected '{1}', got '{2}'" -f $Label, $Expected, $Actual)
  }
}

$cases = @(
  [pscustomobject]@{
    name = "open_download_center_from_home"
    intent = $textOpenDownloadCenter
    url = "https://erp.xinjianerp.com/index/home"
    action_id = "synthetic.page.navigation.download.list"
    type = "navigation"
    source_map = "page_navigation"
    locator_strategy = "navigate_href"
    safety_mode = "safe_execute_allowed"
    forbidden_action_id = "download.list.row_operation"
  },
  [pscustomobject]@{
    name = "download_center_current_page"
    intent = $textDownloadCenter
    url = "https://erp.xinjianerp.com/download/list"
    action_id = "synthetic.page.navigation.download.list"
    type = "navigation"
    source_map = "page_navigation"
    locator_strategy = "navigate_href"
    safety_mode = "safe_execute_allowed"
    forbidden_action_id = "download.list.row_operation"
  },
  [pscustomobject]@{
    name = "open_download_center_without_url"
    intent = $textOpenDownloadCenter
    url = ""
    action_id = "synthetic.page.navigation.download.list"
    type = "navigation"
    source_map = "page_navigation"
    locator_strategy = "navigate_href"
    safety_mode = "safe_execute_allowed"
    forbidden_action_id = "download.list.row_operation"
  },
  [pscustomobject]@{
    name = "open_shop_selector"
    intent = $textOpenShopSelector
    url = "https://erp.xinjianerp.com/index/home"
    action_id = "overlay.index.home.overlay_trigger.$textShopSelector"
    type = "overlay_trigger"
    locator_strategy = "click_trigger_selector"
    safety_mode = "safe_execute_allowed"
  },
  [pscustomobject]@{
    name = "read_shop_column"
    intent = $textViewShopColumn
    url = "https://erp.xinjianerp.com/index/home"
    action_id = "auto.index.home.table.column.$textShop"
    type = "table_column"
    locator_strategy = "read_table_column_header"
    safety_mode = "safe_execute_allowed"
  },
  [pscustomobject]@{
    name = "recent_7_days"
    intent = $textRecent7Days
    url = "https://erp.xinjianerp.com/ad/shop-detail"
    action_id = "ad.shop_detail.filter.date_range"
    type = "date_filter"
    locator_strategy = "click_quick_tab_text_or_placeholder_list"
    safety_mode = "safe_execute_allowed"
  },
  [pscustomobject]@{
    name = "ad_spend_column"
    intent = $textAdSpend
    url = "https://erp.xinjianerp.com/ad/shop-detail"
    action_id = "ad.shop.detail.table.column.$textAdSpend"
    type = "table_column"
    locator_strategy = "read_table_column_header"
    safety_mode = "safe_execute_allowed"
  },
  [pscustomobject]@{
    name = "export_rule_log"
    intent = $textExportRuleLog
    url = "https://erp.xinjianerp.com/erp/ads/rule-log/"
    action_id = "erp.ads.rule_log.export"
    type = "button"
    locator_strategy = "click_visible_dom_text"
    safety_mode = "confirmation_required_export"
  },
  [pscustomobject]@{
    name = "search_creator_id"
    intent = $textSearchCreatorId
    url = "https://erp.xinjianerp.com/crm/matser/management/highSeas"
    action_id = "crm.highseas.filter.creator_id"
    type = "filter_input"
    locator_strategy = "input_or_filter_placeholder"
    safety_mode = "safe_execute_allowed"
  }
)

$results = @()
foreach ($case in $cases) {
  $argsList = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", $queryScript,
    "-Intent", [string]$case.intent,
    "-Json"
  )
  if ($case.url) {
    $argsList += @("-Url", [string]$case.url)
  }

  $raw = @(& powershell @argsList 2>&1)
  $exitCode = $LASTEXITCODE
  $parsed = $null
  $failures = [System.Collections.Generic.List[object]]::new()
  try {
    $parsed = ($raw | Out-String | ConvertFrom-Json)
  } catch {
    Add-Failure -Failures $failures -Message ("query JSON parse failed: {0}" -f $_.Exception.Message)
  }

  $first = $null
  if ($parsed) {
    if ($exitCode -ne 0) {
      Add-Failure -Failures $failures -Message ("query exited with code {0}" -f $exitCode)
    }
    if (!$parsed.ok) {
      Add-Failure -Failures $failures -Message "query returned ok=false"
    }
    $matches = @($parsed.matches)
    if ($matches.Count -eq 0) {
      Add-Failure -Failures $failures -Message "query returned no matches"
    } else {
      $first = $matches[0]
      Test-ExpectedValue -Failures $failures -Label "action.id" -Actual $first.action.id -Expected $case.action_id
      Test-ExpectedValue -Failures $failures -Label "action.type" -Actual $first.action.type -Expected $case.type
      Test-ExpectedValue -Failures $failures -Label "action.source_map" -Actual $first.action.source_map -Expected $case.source_map
      Test-ExpectedValue -Failures $failures -Label "action.locator_strategy" -Actual $first.action.locator_strategy -Expected $case.locator_strategy
      Test-ExpectedValue -Failures $failures -Label "action.safety_mode" -Actual $first.action.safety_mode -Expected $case.safety_mode
      if ($case.forbidden_action_id -and [string]$first.action.id -eq [string]$case.forbidden_action_id) {
        Add-Failure -Failures $failures -Message ("forbidden first action id '{0}'" -f $case.forbidden_action_id)
      }
    }
  }

  $results += [pscustomobject]@{
    name = $case.name
    ok = ($failures.Count -eq 0)
    intent = $case.intent
    url = $case.url
    first_action_id = if ($first) { $first.action.id } else { $null }
    first_action_type = if ($first) { $first.action.type } else { $null }
    first_locator_strategy = if ($first) { $first.action.locator_strategy } else { $null }
    first_safety_mode = if ($first) { $first.action.safety_mode } else { $null }
    failures = @($failures)
  }
}

$exactActionId = "auto.ad.group.detail.button.$textSwitchCurrency"
$exactCases = @(
  [pscustomobject]@{
    name = "exact_action_id_query_without_intent"
    script = $queryScript
    args = @("-ActionId", $exactActionId, "-Url", "https://erp.xinjianerp.com/ad/group-detail", "-Json")
    expect_ok = $true
    expected_action_id = $exactActionId
    expected_page_match_mode = "action_id_exact"
  },
  [pscustomobject]@{
    name = "exact_action_id_rejects_wrong_route"
    script = $queryScript
    args = @("-ActionId", $exactActionId, "-Url", "https://erp.xinjianerp.com/index/home", "-Json")
    expect_ok = $false
    expected_error = "action_id_route_mismatch"
    expected_next_action = "open_or_focus_matching_xinjian_page_route_before_execute"
  },
  [pscustomobject]@{
    name = "exact_action_id_invoke_dry_run"
    script = $invokeScript
    args = @("-ActionId", $exactActionId, "-Url", "https://erp.xinjianerp.com/ad/group-detail", "-NoAutoDetectUrl", "-Json")
    expect_ok = $true
    expected_action_id = $exactActionId
    expected_plan_action_id = $exactActionId
  }
)

foreach ($case in $exactCases) {
  $argsList = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", [string]$case.script
  ) + @($case.args)

  $raw = @(& powershell @argsList 2>&1)
  $exitCode = $LASTEXITCODE
  $parsed = $null
  $failures = [System.Collections.Generic.List[object]]::new()
  try {
    $parsed = ($raw | Out-String | ConvertFrom-Json)
  } catch {
    Add-Failure -Failures $failures -Message ("exact action JSON parse failed: {0}" -f $_.Exception.Message)
  }
  if ($parsed) {
    $expectedOk = [bool]$case.expect_ok
    if ($expectedOk -and $exitCode -ne 0) {
      Add-Failure -Failures $failures -Message ("exact action command exited with code {0}" -f $exitCode)
    }
    if (!$expectedOk -and $exitCode -eq 0) {
      Add-Failure -Failures $failures -Message "exact action command was expected to fail but exited 0"
    }
    if ([bool]$parsed.ok -ne $expectedOk) {
      Add-Failure -Failures $failures -Message ("exact action ok expected '{0}', got '{1}'" -f $expectedOk, [bool]$parsed.ok)
    }
    if ($case.expected_action_id) {
      $actualActionId = if ($parsed.action_id) { [string]$parsed.action_id } elseif (@($parsed.matches).Count -gt 0) { [string]@($parsed.matches)[0].action.id } else { "" }
      Test-ExpectedValue -Failures $failures -Label "exact action id" -Actual $actualActionId -Expected $case.expected_action_id
    }
    if ($case.expected_plan_action_id) {
      Test-ExpectedValue -Failures $failures -Label "plan action.id" -Actual $parsed.plan.action.id -Expected $case.expected_plan_action_id
    }
    if ($case.expected_page_match_mode) {
      Test-ExpectedValue -Failures $failures -Label "page_match_mode" -Actual $parsed.page_match_mode -Expected $case.expected_page_match_mode
    }
    if ($case.expected_error) {
      Test-ExpectedValue -Failures $failures -Label "error" -Actual $parsed.error -Expected $case.expected_error
    }
    if ($case.expected_next_action) {
      Test-ExpectedValue -Failures $failures -Label "next_action" -Actual $parsed.next_action -Expected $case.expected_next_action
    }
  }

  $results += [pscustomobject]@{
    name = $case.name
    ok = ($failures.Count -eq 0)
    intent = ""
    url = ""
    first_action_id = if ($parsed -and @($parsed.matches).Count -gt 0) { @($parsed.matches)[0].action.id } elseif ($parsed -and $parsed.plan) { $parsed.plan.action.id } else { $null }
    first_action_type = if ($parsed -and @($parsed.matches).Count -gt 0) { @($parsed.matches)[0].action.type } elseif ($parsed -and $parsed.plan) { $parsed.plan.action.type } else { $null }
    first_locator_strategy = if ($parsed -and @($parsed.matches).Count -gt 0) { @($parsed.matches)[0].action.locator_strategy } elseif ($parsed -and $parsed.plan) { $parsed.plan.locator_strategy } else { $null }
    first_safety_mode = if ($parsed -and @($parsed.matches).Count -gt 0) { @($parsed.matches)[0].action.safety_mode } elseif ($parsed -and $parsed.plan) { $parsed.plan.safety_mode } else { $null }
    failures = @($failures)
  }
}

$failed = @($results | Where-Object { !$_.ok })
$payload = [ordered]@{
  ok = ($failed.Count -eq 0)
  root = $root
  total = $results.Count
  passed = @($results | Where-Object { $_.ok }).Count
  failed = $failed.Count
  cases = @($results)
}

if ($Json) {
  $payload | ConvertTo-Json -Depth 12
} elseif ($failed.Count -eq 0) {
  Write-Host "XINJIAN_RPA_ROUTING_TEST_OK"
} else {
  Write-Host "XINJIAN_RPA_ROUTING_TEST_FAILED"
  foreach ($item in $failed) {
    Write-Host ("- {0}: {1}" -f $item.name, (@($item.failures) -join "; "))
  }
}

if ($failed.Count -gt 0) { exit 1 }
exit 0
