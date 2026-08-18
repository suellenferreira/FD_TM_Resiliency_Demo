param prefix string
param primaryOriginHostName string
param secondaryOriginHostName string

var profileName = 'afd-${prefix}'
var endpointName = 'app-${prefix}'
var tmName = 'tm-app-${prefix}'

resource profile 'Microsoft.Cdn/profiles@2024-02-01' = {
  name: profileName
  location: 'global'
  sku: {
    name: 'Standard_AzureFrontDoor'
  }
}

resource endpoint 'Microsoft.Cdn/profiles/afdEndpoints@2024-02-01' = {
  parent: profile
  name: endpointName
  location: 'global'
  properties: {
    enabledState: 'Enabled'
  }
}

resource originGroup 'Microsoft.Cdn/profiles/originGroups@2024-02-01' = {
  parent: profile
  name: 'app-origins'
  properties: {
    healthProbeSettings: {
      probePath: '/health'
      probeRequestType: 'GET'
      probeProtocol: 'Https'
      probeIntervalInSeconds: 30
    }
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 0
    }
  }
}

resource primaryOrigin 'Microsoft.Cdn/profiles/originGroups/origins@2024-02-01' = {
  parent: originGroup
  name: 'centralus'
  properties: {
    hostName: primaryOriginHostName
    originHostHeader: primaryOriginHostName
    httpPort: 80
    httpsPort: 443
    priority: 1
    weight: 1000
    enabledState: 'Enabled'
  }
}

resource secondaryOrigin 'Microsoft.Cdn/profiles/originGroups/origins@2024-02-01' = {
  parent: originGroup
  name: 'northcentralus'
  properties: {
    hostName: secondaryOriginHostName
    originHostHeader: secondaryOriginHostName
    httpPort: 80
    httpsPort: 443
    priority: 2
    weight: 1000
    enabledState: 'Enabled'
  }
}

resource route 'Microsoft.Cdn/profiles/afdEndpoints/routes@2024-02-01' = {
  parent: endpoint
  name: 'default'
  dependsOn: [
    primaryOrigin
    secondaryOrigin
  ]
  properties: {
    originGroup: {
      id: originGroup.id
    }
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'HttpsOnly'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
    enabledState: 'Enabled'
  }
}

resource trafficManager 'Microsoft.Network/trafficManagerProfiles@2022-04-01' = {
  name: tmName
  location: 'global'
  properties: {
    profileStatus: 'Enabled'
    trafficRoutingMethod: 'Priority'
    dnsConfig: {
      relativeName: tmName
      ttl: 30
    }
    monitorConfig: {
      protocol: 'HTTPS'
      port: 443
      path: '/health'
      intervalInSeconds: 30
      timeoutInSeconds: 10
      toleratedNumberOfFailures: 3
    }
  }
}

resource primaryTmEndpoint 'Microsoft.Network/trafficManagerProfiles/azureEndpoints@2022-04-01' = {
  parent: trafficManager
  name: 'centralus'
  properties: {
    targetResourceId: resourceId('Microsoft.Web/sites', split(primaryOriginHostName, '.')[0])
    endpointStatus: 'Enabled'
    priority: 1
  }
}

resource secondaryTmEndpoint 'Microsoft.Network/trafficManagerProfiles/azureEndpoints@2022-04-01' = {
  parent: trafficManager
  name: 'northcentralus'
  properties: {
    targetResourceId: resourceId('Microsoft.Web/sites', split(secondaryOriginHostName, '.')[0])
    endpointStatus: 'Enabled'
    priority: 2
  }
}

output frontDoorUrl string = 'https://${endpoint.properties.hostName}'
output trafficManagerFqdn string = trafficManager.properties.dnsConfig.fqdn
