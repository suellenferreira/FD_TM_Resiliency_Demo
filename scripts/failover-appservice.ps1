[CmdletBinding()]
param([ValidateSet('health', 'stop')][string]$Mode = 'health')

. "$PSScriptRoot/common.ps1"
Import-DemoConfig
$appName = Get-DemoName -Workload app -Region cu

if ($Mode -eq 'health') {
  az webapp config appsettings set --resource-group $env:AZURE_RESOURCE_GROUP --name $appName --settings HEALTHY=false | Out-Null
  az webapp restart --resource-group $env:AZURE_RESOURCE_GROUP --name $appName | Out-Null
} else {
  az webapp stop --resource-group $env:AZURE_RESOURCE_GROUP --name $appName | Out-Null
}
Write-Host "App Service primary failure simulation enabled with mode '$Mode'."
