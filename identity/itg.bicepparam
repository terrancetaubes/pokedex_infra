using 'main.bicep'

param environment = 'itg'
param uniqueSuffix = 'itg'
param githubOwner = 'terrancetaubes'
// itg does not own the shared apps. dev creates pokedex-api and pokedex-ui-spa, and sets their redirect URIs.
// Run dev before itg. The values below are ignored in this run.
param ownsSharedApps = false
param uiRedirectUris = []
// false for stage 1, true for stage 2.
param deployWorkloadRbac = false
// App roles are set only by the dev file. Keep these lists empty here.
param adminUserObjectIds = []
param endUserObjectIds = []
