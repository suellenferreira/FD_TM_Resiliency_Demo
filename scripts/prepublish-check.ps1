[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$blockedPatterns = @(
  'AZURE_TENANT_ID=[0-9a-f-]{36}',
  'AZURE_SUBSCRIPTION_ID=[0-9a-f-]{36}',
  'AZURE_RESOURCE_GROUP=RG-',
  '(?<!<)[a-z0-9]+-[a-z0-9-]+\.(trafficmanager\.net|azurefd\.net|azurewebsites\.net|cloudapp\.azure\.com)',
  'BEGIN (RSA|OPENSSH|PRIVATE) KEY',
  '(password|secret|token|clientSecret|connectionString)\s*[=:]'
)

$files = Get-ChildItem $root -Recurse -File | Where-Object {
  $_.FullName -notmatch '\\(\.git|node_modules|outputs)\\' -and
  $_.Name -ne 'prepublish-check.ps1' -and
  $_.Name -notin @('demo.env', 'demo-endpoints.env') -and
  $_.Extension -in @('.bicep', '.yaml', '.yml', '.ps1', '.js', '.md', '.dockerfile', '')
}

$findings = foreach ($file in $files) {
  foreach ($pattern in $blockedPatterns) {
    Select-String -Path $file.FullName -Pattern $pattern -AllMatches | ForEach-Object {
      if ($_.Path -notmatch 'demo\.env\.example' -and $_.Line -notmatch '<(tenant-id|subscription-id|resource-group)>') {
        $_
      }
    }
  }
}

if ($findings) {
  $findings | ForEach-Object { Write-Error "$($_.Path):$($_.LineNumber): $($_.Line.Trim())" }
  throw 'Potential environment-specific data or secret found. Review before publishing.'
}

Write-Output 'Pre-publication check passed. No environment-specific identifiers or secret patterns found in publishable files.'