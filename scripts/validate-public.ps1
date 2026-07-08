param(
  [string]$Root = "",
  [switch]$Json
)

$ErrorActionPreference = "Continue"

if (!$Root) {
  $Root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
} else {
  $Root = (Resolve-Path -LiteralPath $Root).Path
}

$errorItems = @()
$warningItems = @()

function Add-Issue($Level, $Code, $Message, $Path = "") {
  $item = [pscustomobject]@{ level = $Level; code = $Code; message = $Message; path = $Path }
  if ($Level -eq "error") { $script:errorItems += $item } else { $script:warningItems += $item }
}

function Test-TextFile($Path) {
  $ext = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
  if ($ext -in @(".md", ".txt", ".json", ".ps1", ".py", ".csv", ".yml", ".yaml", ".gitignore", ".gitattributes")) { return $true }
  $name = [System.IO.Path]::GetFileName($Path)
  return $name -in @("README", "LICENSE")
}

$builtInPatterns = @(
  ("主" + "人"),
  ("tenant_" + "access_" + "token"),
  ("app_" + "token"),
  ("refresh_" + "token"),
  ("access_" + "token"),
  ("private_" + "key"),
  ("ZINIAO_" + "PASSWORD"),
  ("ZINIAO_" + "USERNAME"),
  ("ZINIAO_" + "COMPANY"),
  ("C:\\Users\\" + "Administrator"),
  ("D:\\UserData\\" + "Desktop"),
  ("E:\\" + "ZiNiao"),
  "(?<![A-Za-z0-9])(?!(?:example|sample|demo)-)[A-Za-z][A-Za-z0-9 ._-]{1,50}-(?:my|th|id|sg|ph|vn)-(?:sp|tt|la)\s*(?:自营|合作)?",
  "tbl[A-Za-z0-9]{8,}",
  "base/[A-Za-z0-9]{12,}",
  "wiki/[A-Za-z0-9]{12,}"
)
$privatePatternsPath = Join-Path $Root "sensitive-patterns.local.txt"
if (Test-Path -LiteralPath $privatePatternsPath) {
  try {
    foreach ($line in Get-Content -LiteralPath $privatePatternsPath) {
      $value = ($line | Out-String).Trim()
      if ($value -and !$value.StartsWith("#")) {
        $builtInPatterns += [regex]::Escape($value)
      }
    }
  } catch {
    Add-Issue "warning" "private_patterns_read_failed" "Failed to read sensitive-patterns.local.txt." $privatePatternsPath
  }
}
$forbidden = [regex]("(?i)" + ($builtInPatterns -join "|"))
$localOnly = @("shops.json", "shops.detected.json", "shops.local.json", "shops.private.json", "shops.csv", "ziniao.local.json", "ziniao.auth.local.json", ".env", ".env.local", "sensitive-patterns.local.txt")
$localOnlyDirs = @(".upstreams", ".ziniao-ops", "reports.local")
$trackedDenyPatterns = @(
  "^\.upstreams/",
  "^\.ziniao-ops/",
  "^reports\.local/",
  "^shops\.json$",
  "^shops\.(detected|local|private)\.json$",
  "^shops\.csv$",
  "^shops\..+\.csv$",
  "^ziniao\.local\.json$",
  "^ziniao\.auth\.local\.json$",
  "^ziniao\..+\.local\.json$",
  "^\.env(\..+)?$",
  "^.+\.env(\..+)?$",
  "^sensitive-patterns\.local\.txt$",
  "^.+\.zip$",
  "^.+\.log$",
  "^.+\.tmp$",
  "^.+\.xlsx$",
  "^.+\.xls$",
  "^.+\.png$",
  "^.+\.jpg$",
  "^.+\.jpeg$",
  "^.+\.pyc$"
)

foreach ($name in $localOnly) {
  $p = Join-Path $Root $name
  if (Test-Path -LiteralPath $p) {
    Add-Issue "warning" "local_file_present" "Local-only file exists. It must not be committed." $p
  }
}
foreach ($name in $localOnlyDirs) {
  $p = Join-Path $Root $name
  if (Test-Path -LiteralPath $p) {
    Add-Issue "warning" "local_dir_present" "Local-only directory exists. It must not be committed or included in release zips." $p
  }
}

$git = Get-Command git -ErrorAction SilentlyContinue
if ($git) {
  $inside = (& git -C $Root rev-parse --is-inside-work-tree 2>$null | Out-String).Trim()
  if ($inside -eq "true") {
    $tracked = @(& git -C $Root ls-files 2>$null)
    foreach ($name in $localOnly) {
      if ($tracked -contains $name) {
        Add-Issue "error" "tracked_local_file" "Local-only file is tracked by git." $name
      }
    }
    foreach ($trackedPath in $tracked) {
      $normalized = $trackedPath -replace "\\", "/"
      if ($normalized -eq "shops.csv.example") { continue }
      foreach ($pattern in $trackedDenyPatterns) {
        if ($normalized -match $pattern) {
          Add-Issue "error" "tracked_denied_file" "Generated, local-only, or sensitive file is tracked by git." $trackedPath
          break
        }
      }
    }
  } else {
    Add-Issue "warning" "not_git_repo" "Root is not a git repository; tracked-file checks were skipped." $Root
  }
} else {
  Add-Issue "warning" "git_missing" "git command not found; tracked-file checks were skipped." ""
}

$files = Get-ChildItem -LiteralPath $Root -Recurse -File -Force | Where-Object {
  $full = $_.FullName
  $name = $_.Name
  $rel = $full.Substring($Root.Length).TrimStart('\', '/')
  $full -notmatch "\\.git\\" -and
  $full -notmatch "\\__pycache__\\" -and
  $full -notmatch "\\.upstreams\\" -and
  $full -notmatch "\\.ziniao-ops\\" -and
  $full -notmatch "\\reports\.local\\" -and
  $rel -ne "scripts\validate-public.ps1" -and
  $name -notlike "*.pyc" -and
  $name -notlike "*.tmp" -and
  $name -notlike "*.log" -and
  $name -notlike "*.zip" -and
  $rel -notin $localOnly
}

foreach ($file in $files) {
  if (!(Test-TextFile $file.FullName)) { continue }
  try {
    $text = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
    $match = $forbidden.Match($text)
    if ($match.Success) {
      Add-Issue "error" "forbidden_text" "Forbidden public text matched: $($match.Value)" $file.FullName
    }
    if ($text.Contains([char]0xFFFD) -or $text -match "鏈|閫|锟") {
      Add-Issue "error" "mojibake" "Possible mojibake or replacement character found." $file.FullName
    }
  } catch {
    Add-Issue "warning" "read_failed" "Failed to read text file as UTF-8: $($_.Exception.Message)" $file.FullName
  }
}

$required = @(
  ".gitignore",
  ".gitattributes",
  "README.md",
  "LICENSE",
  "install.ps1",
  "setup-ziniao.ps1",
  "operate-store.ps1",
  "open-store.ps1",
  "install-codex-skill.ps1",
  "diagnose-local.ps1",
  "shops.template.json",
  "shops.example.json",
  "shops.csv.example",
  "codex-skill\ziniao-ops\SKILL.md",
  "codex-skill\ziniao-ops\agents\openai.yaml",
  "scripts\sync-ziniao-shops.py",
  "scripts\ziniao-gui-open.py",
  "scripts\check-upstreams.ps1",
  "scripts\sync-upstreams.ps1",
  "scripts\status-upstream-adapters.ps1",
  "scripts\path-utils.ps1",
  "scripts\powershell-utils.ps1",
  "scripts\invoke-ziniao-cli.ps1",
  "scripts\invoke-auto-ziniao.ps1",
  "scripts\detect-ziniao-windows.ps1",
  "scripts\get-runtime-status.ps1",
  "scripts\capture-xinjian-ui-map.ps1",
  "scripts\capture-xinjian-dom-map.ps1",
  "scripts\capture-xinjian-dom-cdp.mjs",
  "scripts\query-xinjian-ui-action.ps1",
  "scripts\install-upstream-tools.ps1",
  "scripts\sensitive-text.ps1",
  "scripts\check-external-tools.ps1",
  "scripts\check-ecommerce-tools.ps1",
  "scripts\record-ops-learning.ps1",
  "scripts\show-ops-learning.ps1",
  "scripts\new-ops-task.ps1",
  "scripts\new-ops-batch.ps1",
  "scripts\new-ops-report.ps1",
  "scripts\send-ops-report-lark.ps1",
  "scripts\xinjian-erp-ad-hourly.ps1",
  "scripts\wait-xinjian-export.ps1",
  "scripts\open-xinjian-login.ps1",
  "scripts\fetch-xinjian-browser-data.ps1",
  "scripts\fetch-xinjian-cdp.mjs",
  "scripts\xinjian-ziniao-bridge.ps1",
  "scripts\analyze-xinjian-ad-hourly.py",
  "references\view-intents.md",
  "references\ops-workflows.md",
  "references\ops-workflows.json",
  "references\external-projects.md",
  "references\external-tools.md",
  "references\external-tools.json",
  "references\ecommerce-capability-map.md",
  "references\ecommerce-capability-map.json",
  "references\platform-api-roadmap.md",
  "references\upstreams.md",
  "references\upstreams.json",
  "references\upstream-integration.md",
  "references\xinjian-erp.md",
  "references\xinjian-ui-map.md",
  "references\xinjian-ui-map.json"
)
foreach ($rel in $required) {
  if (!(Test-Path -LiteralPath (Join-Path $Root $rel))) {
    Add-Issue "error" "required_file_missing" "Required public repo file is missing." $rel
  }
}

$skillPath = Join-Path $Root "codex-skill\ziniao-ops\SKILL.md"
if (Test-Path -LiteralPath $skillPath) {
  $skill = Get-Content -LiteralPath $skillPath -Raw
  if (!($skill -match "(?s)^---\s+name:\s*ziniao-ops\s+description:\s+.+?\s+---")) {
    Add-Issue "error" "skill_frontmatter_invalid" "SKILL.md frontmatter is missing or invalid." $skillPath
  }
  $descriptionMatch = [regex]::Match($skill, "(?m)^description:\s*(.+)$")
  if ($descriptionMatch.Success -and $descriptionMatch.Groups[1].Value.Length -gt 1024) {
    Add-Issue "error" "skill_description_too_long" "SKILL.md description exceeds 1024 characters." $skillPath
  }
}

$openaiYamlPath = Join-Path $Root "codex-skill\ziniao-ops\agents\openai.yaml"
if (Test-Path -LiteralPath $openaiYamlPath) {
  $openaiYaml = Get-Content -LiteralPath $openaiYamlPath -Raw
  if (!($openaiYaml -match 'display_name:\s*"Ziniao Ops"')) {
    Add-Issue "error" "openai_yaml_display_name_invalid" "agents/openai.yaml display_name is missing or stale." $openaiYamlPath
  }
  if (!($openaiYaml -match 'default_prompt:\s*".*\$ziniao-ops.*"')) {
    Add-Issue "error" "openai_yaml_prompt_invalid" "agents/openai.yaml default_prompt must mention `$ziniao-ops." $openaiYamlPath
  }
  $shortDescriptionMatch = [regex]::Match($openaiYaml, '(?m)^\s*short_description:\s*"([^"]+)"')
  if ($shortDescriptionMatch.Success) {
    $shortDescriptionLength = $shortDescriptionMatch.Groups[1].Value.Length
    if ($shortDescriptionLength -lt 25 -or $shortDescriptionLength -gt 64) {
      Add-Issue "error" "openai_yaml_short_description_length" "agents/openai.yaml short_description should be 25-64 characters." $openaiYamlPath
    }
  }
}

$psErrors = @()
Get-ChildItem -LiteralPath $Root -Recurse -Filter *.ps1 -File | ForEach-Object {
  try {
    $scriptText = [System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8)
    [scriptblock]::Create($scriptText) | Out-Null
  } catch {
    $psErrors += [pscustomobject]@{ path = $_.FullName; error = $_.Exception.Message }
  }
}
foreach ($err in $psErrors) {
  Add-Issue "error" "powershell_parse_failed" $err.error $err.path
}

$python = Get-Command python -ErrorAction SilentlyContinue
if ($python) {
  foreach ($py in Get-ChildItem -LiteralPath (Join-Path $Root "scripts") -Filter *.py -File -ErrorAction SilentlyContinue) {
    & python -m py_compile $py.FullName 2>$null
    if ($LASTEXITCODE -ne 0) {
      Add-Issue "error" "python_compile_failed" "Python compile failed." $py.FullName
    }
  }
} else {
  Add-Issue "warning" "python_missing" "python command not found; Python compile checks skipped." ""
}

$zipFiles = Get-ChildItem -LiteralPath $Root -Filter *.zip -File -ErrorAction SilentlyContinue
foreach ($zip in $zipFiles) {
  Add-Issue "warning" "zip_present" "Generated zip exists locally. It must not be committed." $zip.FullName
}

$result = [ordered]@{
  ok = ($errorItems.Count -eq 0)
  root = $Root
  errors = @($errorItems)
  warnings = @($warningItems)
}

if ($Json) {
  $result | ConvertTo-Json -Depth 8
} else {
  if ($errorItems.Count -eq 0) {
    Write-Host "PUBLIC_VALIDATE_OK"
  } else {
    Write-Host "PUBLIC_VALIDATE_FAILED"
  }
  foreach ($item in @($errorItems + $warningItems)) {
    Write-Host ("[{0}] {1}: {2} {3}" -f $item.level, $item.code, $item.message, $item.path)
  }
}

if ($errorItems.Count -gt 0) { exit 1 }
