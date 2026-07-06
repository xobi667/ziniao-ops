function Get-ZiniaoOpsSecretKeywordPattern {
  return '(?:\u5bc6\u7801|\u9a8c\u8bc1\u7801|\u6821\u9a8c\u7801|\u52a8\u6001\u7801|\u53e3\u4ee4|\u5bc6\u94a5|\u4ee4\u724c|\u4f1a\u8bdd|(?<![A-Za-z])(?:password|passwd|pwd|secret|token|cookie|session|api[\s_-]*key|private[\s_-]*key|access[\s_-]*token|refresh[\s_-]*token|client[\s_-]*secret)(?![A-Za-z]))'
}

function Get-ZiniaoOpsSecretValuePattern {
  return '(?:\d{4,}|(?=[A-Za-z0-9._~+/=-]{6,}\b)(?=[A-Za-z0-9._~+/=-]*[A-Za-z])(?=[A-Za-z0-9._~+/=-]*\d)[A-Za-z0-9._~+/=-]{6,}|[A-Za-z0-9._~+/=-]{16,})'
}

function Get-ZiniaoOpsSecretRegex {
  return [regex]("(?i)(" + (Get-ZiniaoOpsSecretKeywordPattern) + ')\s*[:=\uFF1A]{1,2}\s*[^\s,;\uFF0C\uFF1B\u3002]+')
}

function Get-ZiniaoOpsSecretSemanticRegex {
  $keyword = Get-ZiniaoOpsSecretKeywordPattern
  $value = Get-ZiniaoOpsSecretValuePattern
  return [regex]("(?i)(" + $keyword + ')\s*(?:\u662F|\u4E3A|\u53EB|\u5982\u4E0B|\bis\b|\bare\b|\bwas\b)\s+(' + $value + ')')
}

function Get-ZiniaoOpsSecretWhitespaceRegex {
  $keyword = Get-ZiniaoOpsSecretKeywordPattern
  $value = Get-ZiniaoOpsSecretValuePattern
  return [regex]("(?i)(" + $keyword + ')\s+(' + $value + ')')
}

function Test-ZiniaoOpsSecretText {
  param([string]$Text)
  if (!$Text) { return $false }
  return ((Get-ZiniaoOpsSecretRegex).IsMatch($Text) -or (Get-ZiniaoOpsSecretSemanticRegex).IsMatch($Text) -or (Get-ZiniaoOpsSecretWhitespaceRegex).IsMatch($Text))
}

function ConvertTo-ZiniaoOpsSafeText {
  param([string]$Text)
  if (!$Text) { return "" }
  $redacted = (Get-ZiniaoOpsSecretRegex).Replace($Text, {
    param($Match)
    $labelPattern = "(?i)^" + (Get-ZiniaoOpsSecretKeywordPattern)
    $label = [regex]::Match($Match.Value, $labelPattern).Value.Trim()
    if (!$label) { $label = "secret" }
    return "$label=<redacted>"
  })
  $redacted = (Get-ZiniaoOpsSecretSemanticRegex).Replace($redacted, {
    param($Match)
    $labelPattern = "(?i)^" + (Get-ZiniaoOpsSecretKeywordPattern)
    $label = [regex]::Match($Match.Value, $labelPattern).Value.Trim()
    if (!$label) { $label = "secret" }
    return "$label=<redacted>"
  })
  return (Get-ZiniaoOpsSecretWhitespaceRegex).Replace($redacted, {
    param($Match)
    $labelPattern = "(?i)^" + (Get-ZiniaoOpsSecretKeywordPattern)
    $label = [regex]::Match($Match.Value, $labelPattern).Value.Trim()
    if (!$label) { $label = "secret" }
    return "$label=<redacted>"
  })
}
