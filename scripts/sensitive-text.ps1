function Get-ZiniaoOpsSecretRegex {
  return [regex]'(?i)(\u5bc6\u7801|\u9a8c\u8bc1\u7801|\u6821\u9a8c\u7801|\u52a8\u6001\u7801|\u53e3\u4ee4|\u5bc6\u94a5|\u4ee4\u724c|\u4f1a\u8bdd|password|passwd|pwd|secret|token|cookie|session|api[\s_-]*key|private[\s_-]*key|access[\s_-]*token|refresh[\s_-]*token|client[\s_-]*secret)\s*(?:[:=\uFF1A]{1,2}|\u662F|\u4E3A|\u53EB|\u5982\u4E0B|\bis\b|\bare\b|\bwas\b|\s+)\s*[^\s,;\uFF0C\uFF1B\u3002]+'
}

function Test-ZiniaoOpsSecretText {
  param([string]$Text)
  if (!$Text) { return $false }
  return (Get-ZiniaoOpsSecretRegex).IsMatch($Text)
}

function ConvertTo-ZiniaoOpsSafeText {
  param([string]$Text)
  if (!$Text) { return "" }
  return (Get-ZiniaoOpsSecretRegex).Replace($Text, {
    param($Match)
    $labelPattern = '(?i)^(\u5bc6\u7801|\u9a8c\u8bc1\u7801|\u6821\u9a8c\u7801|\u52a8\u6001\u7801|\u53e3\u4ee4|\u5bc6\u94a5|\u4ee4\u724c|\u4f1a\u8bdd|password|passwd|pwd|secret|token|cookie|session|api[\s_-]*key|private[\s_-]*key|access[\s_-]*token|refresh[\s_-]*token|client[\s_-]*secret)'
    $label = [regex]::Match($Match.Value, $labelPattern).Value.Trim()
    if (!$label) { $label = "secret" }
    return "$label=<redacted>"
  })
}
