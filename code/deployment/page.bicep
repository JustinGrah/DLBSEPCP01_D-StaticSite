param resourceName string = 'drkkvwuppertaldemo01'
param location string = 'westeurope'
param frontDoorProfileName string = 'drkkvwuppertalfrontdoor'

resource storageAccount 'Microsoft.Storage/storageAccounts@2026-06-01' = {
  name: resourceName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: true
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2026-06-01' = {
  name: 'default'
  parent: storageAccount
  properties: {
    staticWebsite: {
      enabled: true
      errorDocument404Path: '404.html'
      indexDocument: 'index.html'
    }
  }
}

resource frontDoorProfile 'Microsoft.Cdn/profiles@2026-08-01-preview' = {
  name: frontDoorProfileName
  location: 'global'
  sku: {
    name: 'Standard_AzureFrontDoor'
  }
}

resource frontDoorEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2026-08-01-preview' = {
  parent: frontDoorProfile
  name: 'drk-endpoint-${uniqueString(resourceGroup().id)}'
  location: 'global'
  properties: {
    enabledState: 'Enabled'
  }
}

resource frontDoorOriginGroup 'Microsoft.Cdn/profiles/originGroups@2026-08-01-preview' = {
  parent: frontDoorProfile
  name: 'storage-origin-group'
  dependsOn: [
    blobService
  ]
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
    }
    healthProbeSettings: {
      probePath: '/'
      probeRequestType: 'GET'
      probeProtocol: 'Https'
      probeIntervalInSeconds: 100
    }
  }
}

resource frontDoorOrigin 'Microsoft.Cdn/profiles/originGroups/origins@2026-08-01-preview' = {
  parent: frontDoorOriginGroup
  name: 'storage-origin'
  properties: {
    // Verknüpfung mit dem Hostnamen des Blob Storage (ohne https://)
    hostName: replace(replace(storageAccount.properties.primaryEndpoints.web, 'https://', ''), '/', '')
    originHostHeader: replace(replace(storageAccount.properties.primaryEndpoints.web, 'https://', ''), '/', '')
    httpPort: 80
    httpsPort: 443
    enabledState: 'Enabled'
  }
}

resource frontDoorRoute 'Microsoft.Cdn/profiles/afdEndpoints/routes@2026-08-01-preview' = {
  parent: frontDoorEndpoint
  name: 'default-route'
  dependsOn: [
      frontDoorOrigin
  ]
  properties: {
    originGroup: {
      id: frontDoorOriginGroup.id
    }
    supportedProtocols: ['Http', 'Https']
    patternsToMatch: ['/*']
    forwardingProtocol: 'HttpsOnly'
    linkToDefaultDomain: 'Enabled'
  }
}
