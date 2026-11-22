using 'main.bicep'

param environment = 'dev'
param uniqueSuffix = 'dev'
param githubOwner = 'terrancetaubes'
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
