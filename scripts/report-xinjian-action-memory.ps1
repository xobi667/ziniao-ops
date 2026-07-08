[CmdletBinding(PositionalBinding = $false)]
param(
  [string]$CatalogPath = "",
  [int]$MinActions = 5,
  [int]$MaxWeakPages = 20,
  [switch]$IncludeAllPages,
  [switch]$IncludeDetails,
  [switch]$Json
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
if (!$CatalogPath) {
  $CatalogPath = Join-Path $root "references\xinjian-ui-action-catalog.json"
}

if (!(Test-Path -LiteralPath $CatalogPath)) {
  $payload = [ordered]@{
    ok = $false
    error = "xinjian_action_catalog_missing"
    catalog_path = $CatalogPath
    next_action = "run_generate_xinjian_ui_action_catalog"
  }
  if ($Json) { $payload | ConvertTo-Json -Depth 8 } else { Write-Host "Xinjian action catalog missing: $CatalogPath" }
  exit 2
}

function Get-RouteUrl([string]$Route) {
  if (!$Route) { return "" }
  if ($Route -match "^https?://") { return $Route }
  $path = [string]$Route
  if (!$path.StartsWith("/")) { $path = "/" + $path }
  return "https://erp.xinjianerp.com$path"
}

function Get-CountMap($Items) {
  $map = [ordered]@{}
  foreach ($item in @($Items)) {
    $key = [string]$item
    if (!$key) { $key = "unknown" }
    if (!$map.Contains($key)) { $map[$key] = 0 }
    $map[$key] += 1
  }
  return $map
}

function Get-ActionProp($Action, [string]$Name) {
  if ($Action -and $Action.PSObject.Properties.Match($Name).Count -gt 0) {
    return $Action.$Name
  }
  return $null
}

function Convert-PageReportForOutput($Report, [bool]$Detailed) {
  if ($Detailed) { return $Report }
  return [pscustomobject]([ordered]@{
      risk_score = $Report.risk_score
      module = $Report.module
      name = $Report.name
      route = $Report.route
      actions = $Report.actions
      safe_actions = $Report.safe_actions
      write_actions = $Report.write_actions
      export_actions = $Report.export_actions
      table_column_actions = $Report.table_column_actions
      gaps = $Report.gaps
      recommended_command = $Report.recommended_command
    })
}

$catalog = Get-Content -LiteralPath $CatalogPath -Raw -Encoding UTF8 | ConvertFrom-Json
$pages = @($catalog.pages)
$pageReports = @()

foreach ($page in $pages) {
  $actions = @($page.actions)
  $sourceCounts = Get-CountMap ($actions | ForEach-Object { Get-ActionProp $_ "source_map" })
  $typeCounts = Get-CountMap ($actions | ForEach-Object { Get-ActionProp $_ "type" })
  $safetyCounts = Get-CountMap ($actions | ForEach-Object { Get-ActionProp $_ "safety_mode" })
  $locatorCounts = Get-CountMap ($actions | ForEach-Object { Get-ActionProp $_ "locator_strategy" })
  $gaps = @()
  $riskScore = 0

  $manualReview = [int]($safetyCounts["manual_review"])
  $mapOnly = @($actions | Where-Object { (Get-ActionProp $_ "locator_strategy") -eq "map_only_uia_locator" }).Count
  $emptyLocator = @($actions | Where-Object {
      $locator = Get-ActionProp $_ "locator"
      !$locator -or @($locator.PSObject.Properties).Count -eq 0
    }).Count

  if ($actions.Count -eq 0) {
    $gaps += "no_actions"
    $riskScore += 100
  } elseif ($actions.Count -lt $MinActions) {
    $gaps += "low_action_count"
    $riskScore += (40 - $actions.Count)
  }
  if ($manualReview -gt 0) {
    $gaps += "manual_review_actions"
    $riskScore += 80 + $manualReview
  }
  if ($mapOnly -gt 0) {
    $gaps += "map_only_locators"
    $riskScore += 60 + $mapOnly
  }
  if ($emptyLocator -gt 0) {
    $gaps += "empty_locators"
    $riskScore += 60 + $emptyLocator
  }
  if (!$sourceCounts.Contains("overlay")) {
    $gaps += "no_overlay_memory"
    $riskScore += 8
  }
  if (!$sourceCounts.Contains("dialog")) {
    $gaps += "no_dialog_memory"
    $riskScore += 4
  }
  if (!$sourceCounts.Contains("row-action")) {
    $gaps += "no_row_action_memory"
    $riskScore += 2
  }
  if ([int]($safetyCounts["safe_execute_allowed"]) -eq 0) {
    $gaps += "no_safe_actions"
    $riskScore += 20
  }

  $learnUrl = Get-RouteUrl ([string]$page.route)
  if (!$learnUrl -and $page.url_contains) {
    $learnUrl = Get-RouteUrl ([string](@($page.url_contains)[0]))
  }

  $pageReports += [pscustomobject]([ordered]@{
      id = [string]$page.id
      module = [string]$page.module
      name = [string]$page.name
      route = [string]$page.route
      learn_url = $learnUrl
      actions = $actions.Count
      safe_actions = [int]($safetyCounts["safe_execute_allowed"])
      write_actions = [int]($safetyCounts["confirmation_required_write"])
      export_actions = [int]($safetyCounts["confirmation_required_export"])
      table_column_actions = [int]($typeCounts["table_column"])
      manual_review_actions = $manualReview
      map_only_locators = $mapOnly
      empty_locators = $emptyLocator
      sources = $sourceCounts
      types = $typeCounts
      locator_strategies = $locatorCounts
      gaps = $gaps
      risk_score = $riskScore
      recommended_command = if ($learnUrl) { "powershell -ExecutionPolicy Bypass -File (Join-Path `$ZiniaoOpsHome `"scripts\learn-xinjian-current-page.ps1`") -Url `"$learnUrl`" -Json" } else { "" }
    })
}

$weakPages = @($pageReports |
  Where-Object { $_.risk_score -gt 0 } |
  Sort-Object @{ Expression = "risk_score"; Descending = $true }, @{ Expression = "actions"; Ascending = $true }, module, name)
if ($MaxWeakPages -gt 0) {
  $weakPages = @($weakPages | Select-Object -First $MaxWeakPages)
}
$weakPagesForOutput = @($weakPages | ForEach-Object { Convert-PageReportForOutput $_ ([bool]$IncludeDetails) })
$allPagesForOutput = if ($IncludeAllPages) {
  @($pageReports | ForEach-Object { Convert-PageReportForOutput $_ ([bool]$IncludeDetails) })
} else {
  @()
}

$sourceCoverage = [ordered]@{}
foreach ($source in @("curated", "auto", "overlay", "dialog", "row-action")) {
  $sourceCoverage[$source] = @($pageReports | Where-Object { $_.sources.Contains($source) }).Count
}

$payload = [ordered]@{
  ok = $true
  catalog_path = $CatalogPath
  catalog_version = [string]$catalog.version
  totals = $catalog.totals
  audit = [ordered]@{
    manual_review_actions = @($catalog.audit.manual_review_actions).Count
    map_only_actions = @($catalog.audit.map_only_actions).Count
    empty_locator_actions = @($catalog.audit.empty_locator_actions).Count
  }
  thresholds = [ordered]@{
    min_actions = $MinActions
    max_weak_pages = $MaxWeakPages
  }
  source_coverage_pages = $sourceCoverage
  weak_pages_count = @($pageReports | Where-Object { $_.risk_score -gt 0 }).Count
  weak_pages = $weakPagesForOutput
  all_pages = $allPagesForOutput
  next_actions = @(
    "Run learn-xinjian-current-page.ps1 for high-risk pages that are already open or can be opened safely.",
    "Run learn-xinjian-open-pages.ps1 after opening several target pages in the debuggable browser.",
    "Keep write/export actions confirmation-required even when locators are known."
  )
}

if ($Json) {
  $payload | ConvertTo-Json -Depth 18
} else {
  Write-Host ("Xinjian action memory: {0} pages, {1} actions" -f $catalog.totals.pages, $catalog.totals.actions)
  Write-Host ("Audit: manual_review={0}, map_only={1}, empty_locator={2}" -f $payload.audit.manual_review_actions, $payload.audit.map_only_actions, $payload.audit.empty_locator_actions)
  Write-Host ("Weak pages: {0}" -f $payload.weak_pages_count)
  $rows = @($weakPages | ForEach-Object {
      [pscustomobject]@{
        score = $_.risk_score
        module = $_.module
        page = $_.name
        route = $_.route
        actions = $_.actions
        table_columns = $_.table_column_actions
        gaps = ($_.gaps -join ",")
      }
    })
  $rows | Format-Table -AutoSize | Out-String | Write-Output
}
