targetScope = 'resourceGroup'

param prefix string
param primaryOriginHostName string
param secondaryOriginHostName string

var normalizedPrefix = toLower(replace(prefix, '-', ''))
var profileName = 'afd-${normalizedPrefix}'
var endpointName = 'aks-${normalizedPrefix}'
var tmName = 'tm-aks-${normalizedPrefix}'

resource profile 'Microsoft.Cdn/profiles@2024-02-01' existing = {
  name: profileName
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
  name: 'aks-origins'
  properties: {
    healthProbeSettings: {
      probePath: '/health'
      probeRequestType: 'GET'
      probeProtocol: 'Http'
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
    forwardingProtocol: 'HttpOnly'
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
      protocol: 'HTTP'
      port: 80
      path: '/health'
      intervalInSeconds: 30
      timeoutInSeconds: 10
      toleratedNumberOfFailures: 3
    }
  }
}

resource primaryTmEndpoint 'Microsoft.Network/trafficManagerProfiles/externalEndpoints@2022-04-01' = {
  parent: trafficManager
  name: 'centralus'
  properties: {
    target: primaryOriginHostName
    endpointStatus: 'Enabled'
    priority: 1
  }
}

resource secondaryTmEndpoint 'Microsoft.Network/trafficManagerProfiles/externalEndpoints@2022-04-01' = {
  parent: trafficManager
  name: 'northcentralus'
  properties: {
    target: secondaryOriginHostName
    endpointStatus: 'Enabled'
    priority: 2
  }
}

output frontDoorUrl string = 'https://${endpoint.properties.hostName}'
output trafficManagerFqdn string = trafficManager.properties.dnsConfig.fqdn
