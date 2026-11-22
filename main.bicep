// Platform resources for one environment (dev or itg).
// Resource-group scope. Role assignments are NOT here. See identity/rbac.bicep.

targetScope = 'resourceGroup'

@description('Environment name. Matches the GitHub environment and the resource group suffix.')
@allowed([
  'dev'
  'itg'
])
param environmentName string

@description('Suffix for globally unique names, one per environment (dev or itg). Never change.')
@minLength(3)
@maxLength(8)
param uniqueSuffix string

param location string = resourceGroup().location
param namePrefix string = 'pokedex'

@description('Region for the Static Web App. Static Web Apps supports a limited set of regions.')
param swaLocation string = 'eastus2'

@description('Image used until the first CD run replaces it.')
param placeholderImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

var nameSuffix = '${namePrefix}-${environmentName}'
var compactName = toLower('${namePrefix}${environmentName}${uniqueSuffix}')
var queueName = 'pokemon-detail-jobs'
var containerName = 'pokemon'

// User-assigned managed identities. One per workload. Role assignments are in identity/rbac.bicep.
resource agentIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-agent-${nameSuffix}'
  location: location
}

resource functionsIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-functions-${nameSuffix}'
  location: location
}

resource backendIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-backend-${nameSuffix}'
  location: location
}

module observability 'modules/observability.bicep' = {
  name: 'observability'
  params: {
    location: location
    logAnalyticsName: 'log-${nameSuffix}'
    appInsightsName: 'appi-${nameSuffix}'
  }
}

module platform 'modules/platform.bicep' = {
  name: 'platform'
  params: {
    location: location
    acrName: 'cr${compactName}'
    keyVaultName: take('kv-${nameSuffix}-${uniqueSuffix}', 24)
    containerEnvName: 'cae-${nameSuffix}'
    logAnalyticsName: observability.outputs.logAnalyticsName
  }
}

module data 'modules/data.bicep' = {
  name: 'data'
  params: {
    location: location
    storageAccountName: take('st${compactName}', 24)
    containerName: containerName
    queueName: queueName
  }
}

module apps 'modules/apps.bicep' = {
  name: 'apps'
  params: {
    location: location
    swaLocation: swaLocation
    nameSuffix: nameSuffix
    uniqueSuffix: uniqueSuffix
    containerEnvironmentId: platform.outputs.containerEnvironmentId
    acrLoginServer: platform.outputs.acrLoginServer
    storageAccountName: data.outputs.storageAccountName
    storageContainerName: containerName
    queueName: queueName
    appInsightsConnectionString: observability.outputs.appInsightsConnectionString
    placeholderImage: placeholderImage
    agentIdentityId: agentIdentity.id
    agentIdentityClientId: agentIdentity.properties.clientId
    functionsIdentityId: functionsIdentity.id
    functionsIdentityClientId: functionsIdentity.properties.clientId
    backendIdentityId: backendIdentity.id
    backendIdentityClientId: backendIdentity.properties.clientId
  }
}

output agentIdentityName string = agentIdentity.name
output functionsIdentityName string = functionsIdentity.name
output backendIdentityName string = backendIdentity.name
output acrName string = platform.outputs.acrName
output keyVaultName string = platform.outputs.keyVaultName
output storageAccountName string = data.outputs.storageAccountName
output functionsAppName string = apps.outputs.functionsAppName
output agentAppName string = apps.outputs.agentAppName
output backendAppName string = apps.outputs.backendAppName
output staticWebAppName string = apps.outputs.staticWebAppName
