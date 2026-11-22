// Entra ID objects (IAM piece 1) and CI identities (IAM piece 3).
// Each repository gets one CI app per environment. Each has one OIDC federated
// credential whose subject is that GitHub environment. No client secrets.
// Requires the Microsoft Graph Bicep extension and Application.ReadWrite.All
// for the identity pipeline (see docs/BOOTSTRAP.md).
//
// Shared apps (pokedex-api, pokedex-ui-spa) exist once for all environments.
// Only the owning environment (ownsSharedApps = true, dev) creates them.
// Every other environment references them as existing apps. Run dev before itg.

extension microsoftGraphV1

param githubOwner string

@description('Numeric GitHub owner ID (gh api users/<owner> --jq .id). GitHub puts it in the OIDC subject.')
param githubOwnerId string

@description('Numeric GitHub repository ID per repository name (gh api repos/<owner>/<repo> --jq .id).')
param repoIds object

param repos array
param environments array = [
  'dev'
  'itg'
]

@description('True only in the environment that creates the shared apps. Dev is the owner.')
param ownsSharedApps bool = false

@description('Redirect URIs for the UI, one per environment (Static Web Apps hostnames). Used only when ownsSharedApps is true.')
param uiRedirectUris array

@description('Entra object IDs of users who get the admin app role on pokedex-api. Applied only when ownsSharedApps is true.')
param adminUserObjectIds array = []

@description('Entra object IDs of users who get the end-user app role on pokedex-api. Applied only when ownsSharedApps is true.')
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
  // GitHub's OIDC subject uses the owner and repository IDs: repo:<owner>@<ownerId>/<repo>@<repoId>:environment:<env>.
  subject: 'repo:${githubOwner}@${githubOwnerId}/${k.repo}@${repoIds[k.repo]}:environment:${k.env}'
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

// ---- Shared API app: created by the owner, referenced by the others ----
resource apiAppNew 'Microsoft.Graph/applications@v1.0' = if (ownsSharedApps) {
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

resource apiAppExisting 'Microsoft.Graph/applications@v1.0' existing = if (!ownsSharedApps) {
  uniqueName: 'pokedex-api'
}

var apiClientId = ownsSharedApps ? apiAppNew!.appId : apiAppExisting!.appId

// The service principal is the enterprise application. Role assignments point at it.
resource apiServicePrincipalNew 'Microsoft.Graph/servicePrincipals@v1.0' = if (ownsSharedApps) {
  appId: apiClientId
}

resource apiServicePrincipalExisting 'Microsoft.Graph/servicePrincipals@v1.0' existing = if (!ownsSharedApps) {
  appId: apiClientId
}

var apiServicePrincipalId = ownsSharedApps ? apiServicePrincipalNew!.id : apiServicePrincipalExisting!.id

// Assign roles to users. Only the owner applies them. Lists in other environments are ignored.
resource adminRoleAssignments 'Microsoft.Graph/appRoleAssignedTo@v1.0' = [for userId in (ownsSharedApps ? adminUserObjectIds : []): {
  principalId: userId
  resourceId: apiServicePrincipalId
  appRoleId: roleAdminId
}]

resource endUserRoleAssignments 'Microsoft.Graph/appRoleAssignedTo@v1.0' = [for userId in (ownsSharedApps ? endUserObjectIds : []): {
  principalId: userId
  resourceId: apiServicePrincipalId
  appRoleId: roleEndUserId
}]

// ---- UI single-page app: public client, PKCE, no secret. Shared like the API app. ----
resource uiAppNew 'Microsoft.Graph/applications@v1.0' = if (ownsSharedApps) {
  displayName: 'pokedex-ui-spa'
  uniqueName: 'pokedex-ui-spa'
  signInAudience: 'AzureADMyOrg'
  spa: {
    redirectUris: uiRedirectUris
  }
  requiredResourceAccess: [
    {
      resourceAppId: apiClientId
      resourceAccess: [
        {
          id: apiScopeId
          type: 'Scope'
        }
      ]
    }
  ]
}

resource uiAppExisting 'Microsoft.Graph/applications@v1.0' existing = if (!ownsSharedApps) {
  uniqueName: 'pokedex-ui-spa'
}

var uiClientId = ownsSharedApps ? uiAppNew!.appId : uiAppExisting!.appId

output apiAppId string = apiClientId
output uiAppId string = uiClientId
output ciPrincipals array = [for (k, i) in ciKeys: {
  repo: k.repo
  env: k.env
  principalId: ciServicePrincipals[i].id
}]
