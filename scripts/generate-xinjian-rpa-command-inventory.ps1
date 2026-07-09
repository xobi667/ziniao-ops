[CmdletBinding(PositionalBinding = $false)]
param(
  [string]$CatalogPath = "",
  [string]$OutputJsonPath = "",
  [string]$OutputMarkdownPath = "",
  [switch]$Json
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
if (!$CatalogPath) { $CatalogPath = Join-Path $root "references\xinjian-ui-action-catalog.json" }
if (!$OutputJsonPath) { $OutputJsonPath = Join-Path $root "references\xinjian-ui-rpa-command-inventory.json" }
if (!$OutputMarkdownPath) { $OutputMarkdownPath = Join-Path $root "references\xinjian-ui-rpa-command-inventory.md" }

function Read-JsonFile([string]$Path) {
  if (!$Path -or !(Test-Path -LiteralPath $Path)) { return $null }
  try { return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json } catch { return $null }
}

function Get-PropertyValue($Object, [string]$Name, $Fallback = $null) {
  if ($null -eq $Object) { return $Fallback }
  if ($Object.PSObject.Properties.Match($Name).Count -eq 0) { return $Fallback }
  $value = $Object.$Name
  if ($null -eq $value) { return $Fallback }
  return $value
}

function Get-PageUrl($Page) {
  $route = [string](Get-PropertyValue $Page "route" "")
  if (!$route) { return "" }
  if ($route -match "^[A-Za-z][A-Za-z0-9+.-]*://") { return $route }
  if (!$route.StartsWith("/")) { $route = "/" + $route }
  return "https://erp.xinjianerp.com$route"
}

function ConvertTo-NullableValue($Value) {
  if ($null -eq $Value) { return $null }
  $text = [string]$Value
  if (!$text) { return $null }
  return $text
}

function New-RpaCommand {
  param(
    [string]$Script,
    [string]$ActionId,
    [string]$Url,
    [bool]$Execute = $false,
    [bool]$AllowWrite = $false,
    [bool]$AllowExport = $false,
    [bool]$JsonOutput = $true,
    [string]$RowIndexPlaceholder = "",
    [string]$RowTextPlaceholder = ""
  )
  $flags = [ordered]@{
    action_id = $ActionId
    url = ConvertTo-NullableValue $Url
    execute = $Execute
    allow_write = $AllowWrite
    allow_export = $AllowExport
    json = $JsonOutput
    row_index = ConvertTo-NullableValue $RowIndexPlaceholder
    row_text = ConvertTo-NullableValue $RowTextPlaceholder
  }
  return [ordered]@{
    script = $Script
    flags = $flags
  }
}

function Test-RowContextAction($Action) {
  $type = [string](Get-PropertyValue $Action "type" "")
  $strategy = [string](Get-PropertyValue $Action "locator_strategy" "")
  return ($strategy -like "row_context_required*" -or $type -in @("row_action", "row_navigation", "row_operation"))
}

function Test-TableColumnAction($Action) {
  $type = [string](Get-PropertyValue $Action "type" "")
  $strategy = [string](Get-PropertyValue $Action "locator_strategy" "")
  return ($type -eq "table_column" -or $strategy -eq "read_table_column_header")
}

$catalog = Read-JsonFile $CatalogPath
if (!$catalog) {
  $payload = [ordered]@{
    ok = $false
    error = "catalog_missing_or_invalid"
    catalog_path = $CatalogPath
  }
  if ($Json) { $payload | ConvertTo-Json -Depth 6 } else { Write-Host "Catalog missing or invalid: $CatalogPath" }
  exit 2
}

$records = @()
foreach ($page in @($catalog.pages)) {
  $pageUrl = Get-PageUrl $page
  foreach ($action in @($page.actions)) {
    $actionId = [string](Get-PropertyValue $action "id" "")
    if (!$actionId) { continue }
    $safetyMode = [string](Get-PropertyValue $action "safety_mode" "")
    $isWrite = ($safetyMode -eq "confirmation_required_write")
    $isExport = ($safetyMode -eq "confirmation_required_export")
    $isRow = Test-RowContextAction $action
    $isTableColumn = Test-TableColumnAction $action

    $commands = [ordered]@{
      exact_query = New-RpaCommand -Script "scripts\query-xinjian-ui-action.ps1" -ActionId $actionId -Url $pageUrl
      dry_run = New-RpaCommand -Script "scripts\invoke-xinjian-ui-action.ps1" -ActionId $actionId -Url $pageUrl
      execute_safe = $null
      read_table_column = $null
      row_context = $null
      confirmed_write = $null
      confirmed_export = $null
    }

    if ($isTableColumn) {
      $commands.read_table_column = [ordered]@{
        command = New-RpaCommand -Script "scripts\invoke-xinjian-ui-action.ps1" -ActionId $actionId -Url $pageUrl -Execute $true
        requires_debuggable_cdp = $true
        optional_row_filters = [ordered]@{
          row_index = "<1-based visible row number>"
          row_text = "<text visible in the target row>"
        }
        no_click = $true
      }
    } elseif ($isRow) {
      $rowBase = [ordered]@{
        requires_row_context = $true
        row_index_command = New-RpaCommand -Script "scripts\invoke-xinjian-ui-action.ps1" -ActionId $actionId -Url $pageUrl -Execute $true -AllowWrite $isWrite -AllowExport $isExport -RowIndexPlaceholder "<1-based visible row number>"
        row_text_command = New-RpaCommand -Script "scripts\invoke-xinjian-ui-action.ps1" -ActionId $actionId -Url $pageUrl -Execute $true -AllowWrite $isWrite -AllowExport $isExport -RowTextPlaceholder "<text visible in the target row>"
        refuses_default_first_row = $true
      }
      if ($isWrite) { $rowBase.explicit_confirmation_required = "allow_write" }
      if ($isExport) { $rowBase.explicit_confirmation_required = "allow_export" }
      $commands.row_context = $rowBase
    } elseif ($safetyMode -eq "safe_execute_allowed") {
      $commands.execute_safe = New-RpaCommand -Script "scripts\invoke-xinjian-ui-action.ps1" -ActionId $actionId -Url $pageUrl -Execute $true
    }

    if ($isWrite) {
      $commands.confirmed_write = [ordered]@{
        command = New-RpaCommand -Script "scripts\invoke-xinjian-ui-action.ps1" -ActionId $actionId -Url $pageUrl -Execute $true -AllowWrite $true
        explicit_confirmation_required = $true
        after_success = "verify_xinjian_page_state_after_write"
      }
    }
    if ($isExport) {
      $commands.confirmed_export = [ordered]@{
        command = New-RpaCommand -Script "scripts\invoke-xinjian-ui-action.ps1" -ActionId $actionId -Url $pageUrl -Execute $true -AllowExport $true
        explicit_confirmation_required = $true
        after_success = "wait_for_xinjian_export_or_open_download_center"
      }
    }

    $records += [ordered]@{
      page_id = [string](Get-PropertyValue $page "id" "")
      page_name = [string](Get-PropertyValue $page "name" "")
      page_route = [string](Get-PropertyValue $page "route" "")
      page_url = ConvertTo-NullableValue $pageUrl
      action_id = $actionId
      action_name = [string](Get-PropertyValue $action "name" "")
      action_type = [string](Get-PropertyValue $action "type" "")
      safety_mode = $safetyMode
      locator_strategy = [string](Get-PropertyValue $action "locator_strategy" "")
      context = [string](Get-PropertyValue $action "context" "")
      purpose = [string](Get-PropertyValue $action "purpose" "")
      function_source = [string](Get-PropertyValue $action "function_source" "")
      commands = $commands
    }
  }
}

$safeDirect = @($records | Where-Object { $_.commands.execute_safe })
$tableReads = @($records | Where-Object { $_.commands.read_table_column })
$rowCommands = @($records | Where-Object { $_.commands.row_context })
$writeCommands = @($records | Where-Object { $_.commands.confirmed_write })
$exportCommands = @($records | Where-Object { $_.commands.confirmed_export })
$missingPurpose = @($records | Where-Object { !$_.purpose })
$missingCommand = @($records | Where-Object { !$_.commands.dry_run -or !$_.commands.exact_query })

$payload = [ordered]@{
  ok = ($records.Count -eq [int]$catalog.totals.actions -and $missingPurpose.Count -eq 0 -and $missingCommand.Count -eq 0)
  version = [string]$catalog.version
  source_catalog_path = $CatalogPath
  source_catalog_generated_at = [string](Get-PropertyValue $catalog "generated_at" "")
  totals = [ordered]@{
    pages = [int]$catalog.totals.pages
    catalog_actions = [int]$catalog.totals.actions
    inventory_actions = $records.Count
    exact_query_commands = $records.Count
    dry_run_commands = $records.Count
    safe_execute_commands = $safeDirect.Count
    table_read_commands = $tableReads.Count
    row_context_command_templates = $rowCommands.Count
    write_confirmation_commands = $writeCommands.Count
    export_confirmation_commands = $exportCommands.Count
    missing_purpose = $missingPurpose.Count
    missing_exact_or_dry_run_command = $missingCommand.Count
  }
  commands = @($records)
  next_action = if ($records.Count -eq [int]$catalog.totals.actions) { "use_action_id_command_inventory_for_exact_rpa_execution" } else { "regenerate_action_catalog_then_inventory" }
}

$jsonDir = Split-Path -Parent $OutputJsonPath
$mdDir = Split-Path -Parent $OutputMarkdownPath
if ($jsonDir) { New-Item -ItemType Directory -Force -Path $jsonDir | Out-Null }
if ($mdDir) { New-Item -ItemType Directory -Force -Path $mdDir | Out-Null }
$payload | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $OutputJsonPath -Encoding UTF8

$lines = @()
$lines += "# Xinjian RPA Command Inventory"
$lines += ""
$lines += "Generated from the sanitized public action catalog. It stores exact action_id commands, not screenshots or private row data."
$lines += ""
$lines += "## Totals"
$lines += ""
$lines += "- Actions: $($payload.totals.inventory_actions) / catalog $($payload.totals.catalog_actions)"
$lines += "- Exact query commands: $($payload.totals.exact_query_commands)"
$lines += "- Dry-run commands: $($payload.totals.dry_run_commands)"
$lines += "- Safe execute commands: $($payload.totals.safe_execute_commands)"
$lines += "- Table read commands: $($payload.totals.table_read_commands)"
$lines += "- Row-context command templates: $($payload.totals.row_context_command_templates)"
$lines += "- Write confirmation commands: $($payload.totals.write_confirmation_commands)"
$lines += "- Export confirmation commands: $($payload.totals.export_confirmation_commands)"
$lines += ""
$lines += "## How To Use"
$lines += ""
$lines += "- Use commands[].commands.exact_query to select a remembered action by exact ID."
$lines += "- Use commands[].commands.dry_run before execution."
$lines += "- Use execute_safe only for safe non-write actions."
$lines += "- Use read_table_column for visible table values on a debuggable CDP page; it does not click."
$lines += "- Use row_context only after row index/text is known; it never defaults to the first row."
$lines += "- Use confirmed_write or confirmed_export only after explicit confirmation."
$lines += ""
$lines += "## Actions"
$lines += ""
$lines += "| Page | Route | Action | Type | Safety | Strategy | Command mode | Purpose |"
$lines += "| --- | --- | --- | --- | --- | --- | --- | --- |"
foreach ($record in $records) {
  $mode = if ($record.commands.confirmed_export) {
    "confirmed_export"
  } elseif ($record.commands.confirmed_write) {
    "confirmed_write"
  } elseif ($record.commands.row_context) {
    "row_context"
  } elseif ($record.commands.read_table_column) {
    "read_table_column"
  } elseif ($record.commands.execute_safe) {
    "execute_safe"
  } else {
    "dry_run_only"
  }
  $purpose = ([string]$record.purpose) -replace "\|", "/"
  $lines += ("| {0} | {1} | {2} {3} | {4} | {5} | {6} | {7} | {8} |" -f $record.page_name, $record.page_route, $record.action_id, $record.action_name, $record.action_type, $record.safety_mode, $record.locator_strategy, $mode, $purpose)
}
$lines += ""
$lines += "This inventory is generated from public sanitized metadata. It does not contain credentials, cookies, tokens, input values, table row values, or private business data."
$lines | Set-Content -LiteralPath $OutputMarkdownPath -Encoding UTF8

if ($Json) {
  $payload | ConvertTo-Json -Depth 20
} else {
  Write-Host "XINJIAN_RPA_COMMAND_INVENTORY_OK=$($payload.ok)"
  Write-Host "JSON: $OutputJsonPath"
  Write-Host "Markdown: $OutputMarkdownPath"
}

if (!$payload.ok) { exit 1 }
exit 0
