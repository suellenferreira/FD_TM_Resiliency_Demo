. "$PSScriptRoot/common.ps1"
Import-DemoConfig
$cluster = Get-DemoName -Workload aks -Region cu
$workloadName = Get-DemoWorkloadName
az aks start --resource-group $env:AZURE_RESOURCE_GROUP --name $cluster 2>$null
az aks get-credentials --resource-group $env:AZURE_RESOURCE_GROUP --name $cluster --overwrite-existing | Out-Null
kubectl scale "deployment/$workloadName" --replicas=1
kubectl rollout status "deployment/$workloadName" --timeout=180s
Write-Host 'AKS primary workload restored.'
