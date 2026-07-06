function Resolve-ZiniaoOpsRepoPath {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Root,
    [string]$Path
  )
  if (!$Path) { return "" }
  $expanded = [Environment]::ExpandEnvironmentVariables($Path)
  if (!$expanded) { return "" }
  if ([System.IO.Path]::IsPathRooted($expanded)) {
    return [System.IO.Path]::GetFullPath($expanded)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $Root $expanded))
}
