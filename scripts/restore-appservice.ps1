. "$PSScriptRoot/common.ps1"
Import-DemoConfig
$appName = Get-DemoName -Workload app -Region cu
az webapp start --resource-group $env:AZURE_RESOURCE_GROUP --name $appName | Out-Null
az webapp config appsettings set --resource-group $env:AZURE_RESOURCE_GROUP --name $appName --settings HEALTHY=true | Out-Null
az webapp restart --resource-group $env:AZURE_RESOURCE_GROUP --name $appName | Out-Null
Write-Host 'App Service primary restored.'
