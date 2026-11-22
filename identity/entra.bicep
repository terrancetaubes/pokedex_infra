// Entra ID objects (IAM piece 1) and CI identities (IAM piece 3).
// Each repository gets one CI app per environment. Each has one OIDC federated
// credential whose subject is that GitHub environment. No client secrets.
// Requires the Microsoft Graph Bicep extension and Application.ReadWrite.All
// for the identity pipeline (see docs/BOOTSTRAP.md).

extension microsoftGraphV1

param githubOwner string
param repos array
param environments array = [
  'dev'
  'itg'
]

@description('Redirect URIs for the UI, one per environment (Static Web Apps hostnames).')
param uiRedirectUris array

@description('Entra object IDs of users who get the admin app role on pokedex-api. Empty until the user exists in the tenant.')
param adminUserObjectIds array = []

@description('Entra object IDs of users who get the end-user app role on pokedex-api.')
param endUserObjectIds array = []

// Every repo x environment pair. Built with an index loop, because Bicep does not allow a for-expression inside flatten().
var ciKeys = [for i in range(0, length(repos) * length(environments)): {
  repo: repos[i / length(environments)]
  env: environments[i % length(environments)]
}]

// ---- CI apps: one per repository per environment ----
resource ciApps 'Microsoft.Graph/applications@v1.0' = [for k in ciKeys: {
  displayName: 'gh-${k.repo}-${k.env}'
  uniqueName: 'gh-${replace(k.repo, '_', '-')}-${k.env}'
  signInAudience: 'AzureADMyOrg'
}]

resource ciServicePrincipals 'Microsoft.Graph/servicePrincipals@v1.0' = [for (k, i) in ciKeys: {
  appId: ciApps[i].appId
}]

// The GitHub environment is the trust boundary. Any job that uses the environment can sign in.
resource ciFicEnv 'Microsoft.Graph/applications/federatedIdentityCredentials@v1.0' = [for (k, i) in ciKeys: {
  name: '${ciApps[i].uniqueName}/github-env-${k.env}'
  issuer: 'https://token.actions.githubusercontent.com'
  subject: 'repo:${githubOwner}/${k.repo}:environment:${k.env}'
  audiences: [
    'api://AzureADTokenExchange'
  ]
}]

// ---- User-facing API ----
// requestedAccessTokenVersion 2 makes the issuer and audience match the backend's checks.
var apiScopeId = guid('pokedex-api', 'access_as_user')

// App roles. The role value is written to the "roles" claim of the user's access token.
// Roles are assigned to users (not groups). The backend must check the claim (not done yet).
var roleAdminId = guid('pokedex-api', 'role-admin')
var roleEndUserId = guid('pokedex-api', 'role-end-user')

resource apiApp 'Microsoft.Graph/applications@v1.0' = {
  displayName: 'pokedex-api'
  uniqueName: 'pokedex-api'
  signInAudience: 'AzureADMyOrg'
  identifierUris: [
    'api://pokedex-api'
  ]
  api: {
    requestedAccessTokenVersion: 2
    oauth2PermissionScopes: [
      {
        id: apiScopeId
        value: 'access_as_user'
        type: 'User'
        isEnabled: true
        adminConsentDisplayName: 'Use the Pokedex API'
        adminConsentDescription: 'Allows the app to call the Pokedex API as the signed-in user.'
        userConsentDisplayName: 'Use the Pokedex API'
        userConsentDescription: 'Allows the app to call the Pokedex API on your behalf.'
      }
    ]
  }
  appRoles: [
    {
      id: roleAdminId
      value: 'admin'
      displayName: 'Admin'
      description: 'Administrative access to Pokedex. Scope of admin actions is not yet defined.'
      allowedMemberTypes: [
        'User'
      ]
      isEnabled: true
    }
    {
      id: roleEndUserId
      value: 'end-user'
      displayName: 'End user'
      description: 'Standard access to sign in and chat with Pokedex.'
      allowedMemberTypes: [
        'User'
      ]
      isEnabled: true
    }
  ]
}

// The service principal is the enterprise application. Role assignments point at it.
resource apiServicePrincipal 'Microsoft.Graph/servicePrincipals@v1.0' = {
  appId: apiApp.appId
}

// Assign roles to users. Entra stores these as app role assignments on the service principal.
resource adminRoleAssignments 'Microsoft.Graph/appRoleAssignedTo@v1.0' = [for userId in adminUserObjectIds: {
  principalId: userId
  resourceId: apiServicePrincipal.id
  appRoleId: roleAdminId
}]

resource endUserRoleAssignments 'Microsoft.Graph/appRoleAssignedTo@v1.0' = [for userId in endUserObjectIds: {
  principalId: userId
  resourceId: apiServicePrincipal.id
  appRoleId: roleEndUserId
}]

// ---- UI single-page app: public client, PKCE, no secret ----
resource uiApp 'Microsoft.Graph/applications@v1.0' = {
  displayName: 'pokedex-ui-spa'
  uniqueName: 'pokedex-ui-spa'
  signInAudience: 'AzureADMyOrg'
  spa: {
    redirectUris: uiRedirectUris
  }
  requiredResourceAccess: [
    {
      resourceAppId: apiApp.appId
      resourceAccess: [
        {
          id: apiScopeId
          type: 'Scope'
        }
      ]
    }
  ]
}

output apiAppId string = apiApp.appId
output uiAppId string = uiApp.appId
output ciPrincipals array = [for (k, i) in ciKeys: {
  repo: k.repo
  env: k.env
  principalId: ciServicePrincipals[i].id
}]
