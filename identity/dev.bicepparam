using 'main.bicep'

param environment = 'dev'
param uniqueSuffix = 'dev'
param githubOwner = 'terrancetaubes'
// Numeric IDs. GitHub uses them in the OIDC subject. Public identifiers, not secrets.
param githubOwnerId = '146674441'
param repoIds = {
  pokedex_infra: '1467122270'
  pokedex_data_functions: '1467122354'
  pokedex_agent_app: '1467122425'
  pokedex_backend: '1467122493'
  pokedex_ui: '1467122561'
}
// Dev owns the shared apps (pokedex-api, pokedex-ui-spa). Run dev before itg.
param ownsSharedApps = true
// Stage 1: temporary localhost redirect. Stage 2 (after step 4b): list BOTH the dev and the itg
// Static Web App hostnames here. Only this file sets the UI redirect URIs.
param uiRedirectUris = [
  'http://localhost:4280'
]
// false for stage 1, true for stage 2.
param deployWorkloadRbac = false
// App roles on pokedex-api. Object IDs of Entra users. Set by scripts/bootstrap.ps1 or paste by hand.
param adminUserObjectIds = ['fefcfc88-252f-487b-82d5-73a0354d9699']
param endUserObjectIds = []
