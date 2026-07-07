[CmdletBinding(PositionalBinding = $false)]
param(
  [int]$Port = 9339,
  [string[]]$StoreName = @(),
  [int]$Days = 7,
  [string]$StartDate = "",
  [string]$EndDate = "",
  [string]$OutputPath = "",
  [string]$ExcelOutputPath = "",
  [string]$Endpoint = "https://erp.xinjianerp.com/prod-api/erp/ad/data/summary-by-date_v2",
  [switch]$Json
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$StoreName = @(
  foreach ($name in $StoreName) {
    if ($name) {
      $name -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    }
  }
)

if (!$EndDate) {
  $EndDate = (Get-Date).ToString("yyyy-MM-dd")
}
if (!$StartDate) {
  $StartDate = (Get-Date).Date.AddDays(-1 * ([Math]::Max($Days, 1) - 1)).ToString("yyyy-MM-dd")
}

function Get-DevToolsPage {
  param([int]$Port)
  $pages = @(Invoke-RestMethod -Uri "http://127.0.0.1:$Port/json" -TimeoutSec 5)
  $page = $pages |
    Where-Object { $_.webSocketDebuggerUrl -and $_.type -eq "page" -and $_.url -match "erp\.xinjianerp\.com" } |
    Select-Object -First 1
  if (!$page) {
    $page = $pages | Where-Object { $_.webSocketDebuggerUrl -and $_.type -eq "page" } | Select-Object -First 1
  }
  if (!$page) {
    throw "No debuggable browser page was found on port $Port."
  }
  return $page
}

function Invoke-CdpEvaluate {
  param(
    [string]$WebSocketUrl,
    [string]$Expression,
    [int]$TimeoutSec = 45
  )
  $ws = [System.Net.WebSockets.ClientWebSocket]::new()
  $cts = [System.Threading.CancellationTokenSource]::new()
  $cts.CancelAfter($TimeoutSec * 1000)
  $uri = [Uri]$WebSocketUrl
  $ws.ConnectAsync($uri, $cts.Token).GetAwaiter().GetResult()
  try {
    $request = @{
      id = 1
      method = "Runtime.evaluate"
      params = @{
        expression = $Expression
        awaitPromise = $true
        returnByValue = $true
      }
    } | ConvertTo-Json -Depth 10 -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($request)
    $ws.SendAsync(
      [ArraySegment[byte]]::new($bytes),
      [System.Net.WebSockets.WebSocketMessageType]::Text,
      $true,
      $cts.Token
    ).GetAwaiter().GetResult()

    $buffer = New-Object byte[] 131072
    $builder = [System.Text.StringBuilder]::new()
    while ($true) {
      $segment = [ArraySegment[byte]]::new($buffer)
      $receive = $ws.ReceiveAsync($segment, $cts.Token).GetAwaiter().GetResult()
      if ($receive.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Close) {
        throw "DevTools websocket closed before a result was returned."
      }
      $chunk = [System.Text.Encoding]::UTF8.GetString($buffer, 0, $receive.Count)
      [void]$builder.Append($chunk)
      if (!$receive.EndOfMessage) {
        continue
      }
      $messageText = $builder.ToString()
      [void]$builder.Clear()
      $message = $messageText | ConvertFrom-Json
      if ($message.id -eq 1) {
        return $message
      }
    }
  } finally {
    if ($ws.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
      $ws.CloseAsync(
        [System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure,
        "done",
        [System.Threading.CancellationToken]::None
      ).GetAwaiter().GetResult()
    }
    $ws.Dispose()
    $cts.Dispose()
  }
}

function Get-JsonPropertyArray {
  param(
    [object]$Object,
    [string]$Name
  )
  if (!$Object) {
    return @()
  }
  if ($Object.PSObject.Properties.Match($Name).Count -eq 0) {
    return @()
  }
  $value = $Object.$Name
  if ($null -eq $value) {
    return @()
  }
  return @($value | ForEach-Object { $_ })
}

$body = @{
  shopIds = @()
  startTime = "$StartDate 00:00:00"
  endTime = "$EndDate 23:59:59"
  dateType = 1
  currencyType = 1
}
$reportDir = Join-Path $root "reports.local"
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$responsePath = Join-Path $reportDir "$stamp-xinjian-browser-response.json"

$fetchMeta = $null
$node = Get-Command node -ErrorAction SilentlyContinue
$nodeHelper = Join-Path $PSScriptRoot "fetch-xinjian-cdp.mjs"
if ($node -and (Test-Path -LiteralPath $nodeHelper)) {
  $bodyJsonForNode = $body | ConvertTo-Json -Depth 8 -Compress
  $bodyB64ForNode = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($bodyJsonForNode))
  $storesJsonForNode = $StoreName | ConvertTo-Json -Depth 4 -Compress
  $storesB64ForNode = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($storesJsonForNode))
  $nodeOutput = @(& node $nodeHelper `
    --port ([string]$Port) `
    --endpoint $Endpoint `
    --body-b64 $bodyB64ForNode `
    --stores-b64 $storesB64ForNode `
    --out $responsePath 2>&1)
  if ($LASTEXITCODE -eq 0) {
    $fetchMeta = ($nodeOutput | Out-String | ConvertFrom-Json)
  } else {
    throw ("Node CDP fetch failed: " + ($nodeOutput | Out-String))
  }
} else {
  $page = Get-DevToolsPage -Port $Port
  $endpointJs = $Endpoint | ConvertTo-Json -Compress
  $bodyJs = $body | ConvertTo-Json -Depth 8 -Compress
  $expression = @"
(async () => {
  const endpoint = $endpointJs;
  const body = $bodyJs;
  const response = await fetch(endpoint, {
    method: "POST",
    headers: { "content-type": "application/json;charset=UTF-8" },
    body: JSON.stringify(body),
    credentials: "include"
  });
  return { status: response.status, text: await response.text(), href: location.href };
})()
"@
  $eval = Invoke-CdpEvaluate -WebSocketUrl $page.webSocketDebuggerUrl -Expression $expression
  if ($eval.PSObject.Properties.Match("error").Count -gt 0 -and $eval.error) {
    throw ("DevTools evaluation failed: " + ($eval.error | ConvertTo-Json -Compress))
  }
  if ($eval.result.PSObject.Properties.Match("exceptionDetails").Count -gt 0 -and $eval.result.exceptionDetails) {
    throw ("Browser fetch threw an exception: " + ($eval.result.exceptionDetails | ConvertTo-Json -Compress -Depth 8))
  }
  $value = $eval.result.result.value
  [System.IO.File]::WriteAllText($responsePath, [string]$value.text, [System.Text.Encoding]::UTF8)
  $fetchMeta = [pscustomobject]@{
    page_url = $value.href
    http_status = $value.status
    response_path = $responsePath
  }
}

$responseText = [System.IO.File]::ReadAllText($responsePath, [System.Text.Encoding]::UTF8)

$responseJson = $null
try {
  $responseJson = $responseText | ConvertFrom-Json
} catch {
  $responseJson = [pscustomobject]@{
    code = $null
    msg = "Response was not JSON."
  }
}

$analysis = $null
if ($responseJson -and $responseJson.code -ne 401) {
  $argsList = @(
    "-ExecutionPolicy", "Bypass",
    "-File", (Join-Path $PSScriptRoot "xinjian-erp-ad-hourly.ps1"),
    "-InputPath", $responsePath,
    "-StoreName", ($StoreName -join ","),
    "-StartDate", $StartDate,
    "-EndDate", $EndDate,
    "-Json"
  )
  if ($OutputPath) { $argsList += @("-OutputPath", $OutputPath) }
  if ($ExcelOutputPath) { $argsList += @("-ExcelOutputPath", $ExcelOutputPath) }
  $rawAnalysis = & powershell @argsList
  try {
    $analysis = ($rawAnalysis | Out-String | ConvertFrom-Json)
  } catch {
    $analysis = [pscustomobject]@{
      ok = $false
      parse_failed = $true
      raw = ($rawAnalysis | Out-String)
    }
  }
}

$storesNotFound = Get-JsonPropertyArray -Object $fetchMeta -Name "stores_not_found"
$storesMatched = Get-JsonPropertyArray -Object $fetchMeta -Name "stores_matched"
$loginState = if ($fetchMeta -and $fetchMeta.PSObject.Properties.Match("login_state").Count -gt 0) {
  $fetchMeta.login_state
} elseif ($responseJson.code -eq 401) {
  "not_logged_in"
} else {
  "unknown"
}

$result = [ordered]@{
  ok = [bool]($analysis -and $analysis.ok)
  login_state = $loginState
  fetch_method = if ($fetchMeta) { $fetchMeta.method } else { $null }
  page_url = $fetchMeta.page_url
  page_title = if ($fetchMeta) { $fetchMeta.page_title } else { $null }
  has_password_input = if ($fetchMeta) { $fetchMeta.has_password_input } else { $null }
  http_status = $fetchMeta.http_status
  response_code = $responseJson.code
  response_msg = $responseJson.msg
  login_required = ($loginState -eq "not_logged_in" -or $responseJson.code -eq 401)
  stores_requested = if ($fetchMeta) { $fetchMeta.stores_requested } else { $StoreName }
  stores_matched = @($storesMatched)
  stores_not_found = @($storesNotFound)
  store_suggestions = if ($fetchMeta) { $fetchMeta.store_suggestions } else { $null }
  per_store = if ($fetchMeta) { $fetchMeta.per_store } else { @() }
  response_path = $responsePath
  analysis = $analysis
  output = if ($analysis) { $analysis.output } else { $null }
  excel_output = if ($analysis) { $analysis.excel_output } else { $null }
  next_action = $null
}
if (!$result.ok) {
  if ($result.login_required) {
    $result.next_action = "manual_login_required"
  } elseif ($storesMatched.Count -eq 0 -and $storesNotFound.Count -gt 0) {
    $result.next_action = "target_stores_not_found_in_xinjian"
  } else {
    $result.next_action = "check_response_or_export_hourly_data"
  }
} elseif ($storesNotFound.Count -gt 0) {
  $result.next_action = "some_requested_stores_not_found_in_xinjian"
}

if ($Json) {
  $result | ConvertTo-Json -Depth 12
} else {
  if ($result.ok) {
    Write-Host "XINJIAN_BROWSER_FETCH_OK"
    Write-Host "Excel: $($result.excel_output)"
  } elseif ($result.login_required) {
    Write-Host "XINJIAN_BROWSER_LOGIN_REQUIRED"
    Write-Host "Complete login in the opened browser, then run this script again."
  } else {
    Write-Host "XINJIAN_BROWSER_FETCH_NO_REPORT"
    Write-Host "Response saved: $responsePath"
  }
}
