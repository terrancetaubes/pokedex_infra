// Workloads: Function App (data pipeline), agent and backend Container Apps, and the UI Static Web App.
// Container Apps start with a placeholder image. The CD workflows replace it.

param location string
param swaLocation string
param nameSuffix string
param uniqueSuffix string
param containerEnvironmentId string
param acrLoginServer string
param storageAccountName string
param storageContainerName string
param queueName string
param appInsightsConnectionString string
param placeholderImage string
param agentIdentityId string
param agentIdentityClientId string
param functionsIdentityId string
param functionsIdentityClientId string
param backendIdentityId string
param backendIdentityClientId string

var queueServiceUri = 'https://${storageAccountName}.queue.${environment().suffixes.storage}'

resource functionPlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: 'asp-${nameSuffix}'
  location: location
  kind: 'functionapp'
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {
    reserved: true
  }
}

resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: 'func-${nameSuffix}-${uniqueSuffix}'
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${functionsIdentityId}': {}
    }
  }
  properties: {
    serverFarmId: functionPlan.id
    httpsOnly: true
    reserved: true
    siteConfig: {
      linuxFxVersion: 'Python|3.11'
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      appSettings: [
        { name: 'FUNCTIONS_EXTENSION_VERSION', value: '~4' }
        { name: 'FUNCTIONS_WORKER_RUNTIME', value: 'python' }
        { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: appInsightsConnectionString }
        { name: 'AzureWebJobsStorage__accountName', value: storageAccountName }
        { name: 'AzureWebJobsStorage__credential', value: 'managedidentity' }
        { name: 'AzureWebJobsStorage__clientId', value: functionsIdentityClientId }
        { name: 'AZURE_CLIENT_ID', value: functionsIdentityClientId }
        { name: 'STORAGE_ACCOUNT_NAME', value: storageAccountName }
        { name: 'STORAGE_CONTAINER_NAME', value: storageContainerName }
        { name: 'POKEMON_QUEUE_NAME', value: queueName }
        { name: 'PokemonQueue__queueServiceUri', value: queueServiceUri }
      ]
    }
  }
}

resource agentApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'ca-agent-${nameSuffix}'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${agentIdentityId}': {}
    }
  }
  properties: {
    environmentId: containerEnvironmentId
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: false
        targetPort: 8000
        transport: 'auto'
      }
      registries: [
        {
          server: acrLoginServer
          identity: agentIdentityId
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'agent'
          image: placeholderImage
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            { name: 'AZURE_CLIENT_ID', value: agentIdentityClientId }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
      }
    }
  }
}

resource backendApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'ca-backend-${nameSuffix}'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${backendIdentityId}': {}
    }
  }
  properties: {
    environmentId: containerEnvironmentId
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 8000
        transport: 'auto'
      }
      registries: [
        {
          server: acrLoginServer
          identity: backendIdentityId
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'backend'
          image: placeholderImage
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            { name: 'AZURE_CLIENT_ID', value: backendIdentityClientId }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
      }
    }
  }
}

resource staticWebApp 'Microsoft.Web/staticSites@2023-12-01' = {
  name: 'swa-${nameSuffix}-${uniqueSuffix}'
  location: swaLocation
  sku: {
    name: 'Free'
    tier: 'Free'
  }
  properties: {}
}

output functionsAppName string = functionApp.name
output agentAppName string = agentApp.name
output backendAppName string = backendApp.name
output staticWebAppName string = staticWebApp.name
