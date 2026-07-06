function ConvertTo-ZiniaoOpsPowerShellLiteral {
  param([string]$Value)
  if ($null -eq $Value) { return "''" }
  return "'" + ($Value -replace "'", "''") + "'"
}
