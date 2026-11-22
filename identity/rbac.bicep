// RBAC role assignments for one environment (IAM pieces 2 and 3).
// Workload access (IAM piece 2). Needs the platform resources, so it runs only after the first platform deployment.
// Scope: this resource group only. Every assignment is the least role the workload needs.

targetScope = 'resourceGroup'

param agentIdentityName string
param functionsIdentityName string
param backendIdentityName string
param storageAccountName string
param keyVaultName string
param acrName string

// Built-in role definition IDs.
var roleContributor = 'b24988ac-6180-42a0-ab88-20f7382dd24c'
var roleStorageBlobDataOwner = 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
var roleStorageQueueDataContributor = '974c5e8b-45b9-4653-ba55-5f855dd0fb88'
var roleKeyVaultSecretsUser = '4633458b-17de-408a-b874-0445c86b69e6'
var roleAcrPull = '7f951dda-4ed3-4680-a7ca-43fe172d538d'

resource agentIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: agentIdentityName
}

resource functionsIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: functionsIdentityName
}

resource backendIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: backendIdentityName
}

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: acrName
}

// Functions host: identity-based AzureWebJobsStorage needs blob owner (leases) and queue access.
resource functionsBlobRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storage.id, functionsIdentity.id, roleStorageBlobDataOwner)
  scope: storage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleStorageBlobDataOwner)
    principalId: functionsIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource functionsQueueRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storage.id, functionsIdentity.id, roleStorageQueueDataContributor)
  scope: storage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleStorageQueueDataContributor)
    principalId: functionsIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Agent: read secrets from Key Vault and pull images. It no longer touches the data lake.
resource agentKeyVaultRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, agentIdentity.id, roleKeyVaultSecretsUser)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleKeyVaultSecretsUser)
    principalId: agentIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource agentAcrRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, agentIdentity.id, roleAcrPull)
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleAcrPull)
    principalId: agentIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Backend: pull images only. It calls the agent app with a token.
resource backendAcrRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, backendIdentity.id, roleAcrPull)
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleAcrPull)
    principalId: backendIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}
