targetScope = 'resourceGroup'

@minLength(3)
@maxLength(10)
param prefix string
param locationPrimary string = 'centralus'
param locationSecondary string = 'northcentralus'
param deployAks bool = true
param appServiceSku string = 'B1'
param aksNodeVmSize string = 'Standard_B2s'

var normalizedPrefix = toLower(replace(prefix, '-', ''))
var appPrimaryName = 'app-${normalizedPrefix}-cu'
var appSecondaryName = 'app-${normalizedPrefix}-ncu'
var acrName = take('acr${normalizedPrefix}${uniqueString(resourceGroup().id)}', 50)
var aksPrimaryName = 'aks-${normalizedPrefix}-cu'
var aksSecondaryName = 'aks-${normalizedPrefix}-ncu'

module appPrimary 'modules/appservice.bicep' = {
  name: 'app-primary'
  params: {
    appName: appPrimaryName
    planName: 'asp-${normalizedPrefix}-cu'
    location: locationPrimary
    skuName: appServiceSku
    regionLabel: 'Central US'
  }
}

module appSecondary 'modules/appservice.bicep' = {
  name: 'app-secondary'
  params: {
    appName: appSecondaryName
    planName: 'asp-${normalizedPrefix}-ncu'
    location: locationSecondary
    skuName: appServiceSku
    regionLabel: 'North Central US'
  }
}

module containerRegistry 'modules/acr.bicep' = if (deployAks) {
  name: 'container-registry'
  params: {
    registryName: acrName
    location: locationPrimary
  }
}

module aksPrimary 'modules/aks.bicep' = if (deployAks) {
  name: 'aks-primary'
  params: {
    clusterName: aksPrimaryName
    location: locationPrimary
    dnsPrefix: '${normalizedPrefix}-cu'
    nodeVmSize: aksNodeVmSize
    acrId: containerRegistry!.outputs.id
  }
}

module aksSecondary 'modules/aks.bicep' = if (deployAks) {
  name: 'aks-secondary'
  params: {
    clusterName: aksSecondaryName
    location: locationSecondary
    dnsPrefix: '${normalizedPrefix}-ncu'
    nodeVmSize: aksNodeVmSize
    acrId: containerRegistry!.outputs.id
  }
}

module globalApp 'modules/global-appservice.bicep' = {
  name: 'global-appservice'
  params: {
    prefix: normalizedPrefix
    primaryOriginHostName: appPrimary.outputs.defaultHostName
    secondaryOriginHostName: appSecondary.outputs.defaultHostName
  }
}

output appServicePrimaryUrl string = 'https://${appPrimary.outputs.defaultHostName}'
output appServiceSecondaryUrl string = 'https://${appSecondary.outputs.defaultHostName}'
output frontDoorAppUrl string = globalApp.outputs.frontDoorUrl
output trafficManagerAppFqdn string = globalApp.outputs.trafficManagerFqdn
output acrLoginServer string = deployAks ? containerRegistry!.outputs.loginServer : ''
output aksPrimaryName string = deployAks ? aksPrimary!.outputs.name : ''
output aksSecondaryName string = deployAks ? aksSecondary!.outputs.name : ''
