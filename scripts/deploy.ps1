[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/common.ps1"
Import-DemoConfig

az account show --query tenantId -o tsv | Out-Null
if ($LASTEXITCODE -ne 0) {
  az login --tenant $env:AZURE_TENANT_ID | Out-Null
  Assert-LastExitCode 'Azure login'
}
az account set --subscription $env:AZURE_SUBSCRIPTION_ID
Assert-LastExitCode 'Selecting Azure subscription'
Assert-AzureContext

$zipPath = Join-Path $env:TEMP 'fd-tm-demo.zip'
Remove-Item $zipPath -ErrorAction SilentlyContinue
Compress-Archive -Path (Join-Path $PSScriptRoot '..\app\server.js') -DestinationPath $zipPath

az group create --name $env:AZURE_RESOURCE_GROUP --location $env:AZURE_LOCATION_PRIMARY | Out-Null
Assert-LastExitCode 'Creating resource group'
$deployAks = if ($env:DEPLOY_AKS.ToLowerInvariant() -eq 'true') { 'true' } else { 'false' }
$deploymentJson = az deployment group create --resource-group $env:AZURE_RESOURCE_GROUP --template-file "$PSScriptRoot\..\infra\main.bicep" --parameters "prefix=$env:DEMO_PREFIX" "locationPrimary=$env:AZURE_LOCATION_PRIMARY" "locationSecondary=$env:AZURE_LOCATION_SECONDARY" "deployAks=$deployAks" --query properties.outputs -o json
Assert-LastExitCode 'Deploying Bicep infrastructure'
$outputs = $deploymentJson | ConvertFrom-Json

foreach ($region in 'cu', 'ncu') {
  az webapp deploy --resource-group $env:AZURE_RESOURCE_GROUP --name (Get-DemoName -Workload app -Region $region) --src-path $zipPath --type zip | Out-Null
  Assert-LastExitCode "Deploying App Service package to $region"
}

$endpointLines = @(
  "APP_PRIMARY_URL=$($outputs.appServicePrimaryUrl.value)",
  "APP_SECONDARY_URL=$($outputs.appServiceSecondaryUrl.value)",
  "FD_APP_URL=$($outputs.frontDoorAppUrl.value)",
  "TM_APP_FQDN=$($outputs.trafficManagerAppFqdn.value)"
)

if ($env:DEPLOY_AKS -eq 'true') {
  $image = "$($outputs.acrLoginServer.value)/fd-tm-demo:v1"
  $workloadName = Get-DemoWorkloadName
  az acr build --registry $outputs.acrLoginServer.value.Split('.')[0] --image 'fd-tm-demo:v1' --file "$PSScriptRoot\..\app\Dockerfile" "$PSScriptRoot\..\app" | Out-Null
  Assert-LastExitCode 'Building container image in ACR'
  foreach ($region in 'cu', 'ncu') {
    $cluster = Get-DemoName -Workload aks -Region $region
    $regionLabel = if ($region -eq 'cu') { 'Central US' } else { 'North Central US' }
    $dnsLabel = "$($env:DEMO_PREFIX.ToLower() -replace '-', '')-$region"
    az aks get-credentials --resource-group $env:AZURE_RESOURCE_GROUP --name $cluster --overwrite-existing | Out-Null
    Assert-LastExitCode "Getting AKS credentials for $region"
    $manifest = (Get-Content "$PSScriptRoot\..\k8s\deployment.yaml" -Raw).Replace('__APP_NAME__', $workloadName).Replace('__IMAGE__', $image).Replace('__REGION__', $regionLabel).Replace('__DNS_LABEL__', $dnsLabel)
    $manifest | kubectl apply -f - | Out-Null
    Assert-LastExitCode "Applying AKS manifest to $region"
    kubectl rollout status "deployment/$workloadName" --timeout=180s | Out-Null
    Assert-LastExitCode "Waiting for AKS workload in $region"
  }
  $primaryFqdn = "$($env:DEMO_PREFIX.ToLower() -replace '-', '')-cu.$($env:AZURE_LOCATION_PRIMARY).cloudapp.azure.com"
  az aks get-credentials --resource-group $env:AZURE_RESOURCE_GROUP --name (Get-DemoName -Workload aks -Region ncu) --overwrite-existing | Out-Null
  Assert-LastExitCode 'Getting AKS secondary credentials'
  $secondaryFqdn = "$($env:DEMO_PREFIX.ToLower() -replace '-', '')-ncu.$($env:AZURE_LOCATION_SECONDARY).cloudapp.azure.com"
  $aksDeploymentJson = az deployment group create --resource-group $env:AZURE_RESOURCE_GROUP --template-file "$PSScriptRoot\..\infra\global-aks.bicep" --parameters "prefix=$env:DEMO_PREFIX" "primaryOriginHostName=$primaryFqdn" "secondaryOriginHostName=$secondaryFqdn" --query properties.outputs -o json
  Assert-LastExitCode 'Deploying AKS global routing'
  $aksOutputs = $aksDeploymentJson | ConvertFrom-Json
  $endpointLines += "AKS_PRIMARY_URL=http://$primaryFqdn", "AKS_SECONDARY_URL=http://$secondaryFqdn", "FD_AKS_URL=$($aksOutputs.frontDoorUrl.value)", "TM_AKS_FQDN=$($aksOutputs.trafficManagerFqdn.value)"
}

New-Item -ItemType Directory -Path "$PSScriptRoot\..\outputs" -Force | Out-Null
$endpointLines | Set-Content "$PSScriptRoot\..\outputs\demo-endpoints.env"
Write-Host 'Deployment completed. Endpoints are in outputs/demo-endpoints.env.'
