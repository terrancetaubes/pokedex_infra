// CI access for one environment (IAM piece 3). Contributor on this resource group only.
// Needs no platform resources, so it runs before the first platform deployment.
// TRADE-OFF: Contributor is broad. Narrow it once the workloads are stable.

targetScope = 'resourceGroup'

@description('Object IDs of the CI service principals for this environment.')
param ciPrincipalIds array

var roleContributor = 'b24988ac-6180-42a0-ab88-20f7382dd24c'

resource ciContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for principalId in ciPrincipalIds: {
  name: guid(resourceGroup().id, principalId, roleContributor)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleContributor)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}]
