using 'main.bicep'

param environment = 'itg'
param uniqueSuffix = 'itg'
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
// itg does not own the shared apps. dev creates pokedex-api and pokedex-ui-spa, and sets their redirect URIs.
// Run dev before itg. The values below are ignored in this run.
param ownsSharedApps = false
param uiRedirectUris = []
// false for stage 1, true for stage 2.
param deployWorkloadRbac = false
// App roles are set only by the dev file. Keep these lists empty here.
param adminUserObjectIds = []
param endUserObjectIds = []
