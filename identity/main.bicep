// IAM entry point for one environment. Run from the identity GitHub environment only.
// Two stages:
//   Stage 1 (deployWorkloadRbac = false): Entra objects and CI access. Run before the first platform deployment.
//   Stage 2 (deployWorkloadRbac = true):  workload role assignments. Run after the platform exists.

targetScope = 'resourceGroup'

@description('Environment to grant access in. Matches the resource group rg-pokedex-<environment>.')
@allowed([
  'dev'
  'itg'
])
param environment string

@description('Same suffix as parameters/<environment>.bicepparam. Never change.')
@minLength(3)
@maxLength(8)
param uniqueSuffix string

param githubOwner string

@description('UI redirect URIs for all environments. Use http://localhost:4280 until the Static Web Apps exist. Read only when ownsSharedApps is true.')
param uiRedirectUris array

@description('True only in the owning environment (dev). It creates pokedex-api and pokedex-ui-spa. Run dev before itg.')
param ownsSharedApps bool = false

@description('Stage 2 switch. Set to true only after the platform deployment has created the workload resources.')
param deployWorkloadRbac bool = false

param repos array = [
  'pokedex_infra'
  'pokedex_data_functions'
  'pokedex_agent_app'
  'pokedex_backend'
  'pokedex_ui'
]

@description('Users who get the admin app role on pokedex-api. Object IDs, from the Entra user.')
param adminUserObjectIds array = []

@description('Users who get the end-user app role on pokedex-api. Object IDs, from the Entra user.')
param endUserObjectIds array = []

// These names must match modules in main.bicep. Change both files together.
var nameSuffix = 'pokedex-${environment}'
var compactName = toLower('pokedex${environment}${uniqueSuffix}')

module entra 'entra.bicep' = {
  name: 'entra-identities'
  params: {
    githubOwner: githubOwner
    repos: repos
    ownsSharedApps: ownsSharedApps
    uiRedirectUris: uiRedirectUris
    adminUserObjectIds: adminUserObjectIds
    endUserObjectIds: endUserObjectIds
  }
}

// Only the CI identities for this environment get Contributor on this resource group.
var envCiPrincipalIds = map(filter(entra.outputs.ciPrincipals, p => p.env == environment), p => p.principalId)

module rbacCi 'rbac-ci.bicep' = {
  name: 'rbac-ci-${environment}'
  params: {
    ciPrincipalIds: envCiPrincipalIds
  }
}

module rbacWorkloads 'rbac.bicep' = if (deployWorkloadRbac) {
  name: 'rbac-workloads-${environment}'
  params: {
    agentIdentityName: 'id-agent-${nameSuffix}'
    functionsIdentityName: 'id-functions-${nameSuffix}'
    backendIdentityName: 'id-backend-${nameSuffix}'
    storageAccountName: take('st${compactName}', 24)
    keyVaultName: take('kv-${nameSuffix}-${uniqueSuffix}', 24)
    acrName: 'cr${compactName}'
  }
}

// Client IDs are identifiers, not secrets. identity.yml writes them to the run summary.
// pokedex-ui-spa is one app for all environments: this is the UI_CLIENT_ID for pokedex_ui.
output uiAppId string = entra.outputs.uiAppId
output apiAppId string = entra.outputs.apiAppId
