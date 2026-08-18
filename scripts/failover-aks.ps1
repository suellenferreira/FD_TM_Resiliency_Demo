[CmdletBinding()]
param([ValidateSet('workload', 'cluster-stop')][string]$Mode = 'workload')

. "$PSScriptRoot/common.ps1"
Import-DemoConfig
$cluster = Get-DemoName -Workload aks -Region cu
$workloadName = Get-DemoWorkloadName

if ($Mode -eq 'workload') {
  az aks get-credentials --resource-group $env:AZURE_RESOURCE_GROUP --name $cluster --overwrite-existing | Out-Null
  kubectl scale "deployment/$workloadName" --replicas=0
} else {
  az aks stop --resource-group $env:AZURE_RESOURCE_GROUP --name $cluster
}
Write-Host "AKS primary failure simulation enabled with mode '$Mode'."
