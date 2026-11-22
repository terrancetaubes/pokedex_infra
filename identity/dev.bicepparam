using 'main.bicep'

param environment = 'dev'
param uniqueSuffix = 'dev'
param githubOwner = 'terrancetaubes'
// Stage 1: temporary localhost redirect. Stage 2 (after step 4b): the two Static Web App hostnames.
param uiRedirectUris = [
  'http://localhost:4280'
]
// false for stage 1, true for stage 2.
param deployWorkloadRbac = false
// App roles on pokedex-api. Object IDs of Entra users. Set by scripts/bootstrap.ps1 or paste by hand.
param adminUserObjectIds = []
param endUserObjectIds = []
