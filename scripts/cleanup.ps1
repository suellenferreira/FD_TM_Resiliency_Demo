[CmdletBinding(SupportsShouldProcess)]
param()

. "$PSScriptRoot/common.ps1"
Import-DemoConfig
if ($PSCmdlet.ShouldProcess($env:AZURE_RESOURCE_GROUP, 'Delete Azure resource group')) {
  az group delete --name $env:AZURE_RESOURCE_GROUP --yes --no-wait
  Remove-Item "$PSScriptRoot\..\outputs" -Recurse -Force -ErrorAction SilentlyContinue
}