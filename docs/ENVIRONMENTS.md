# Environments

See `../../docs/BRANCHING_AND_RELEASE.md` for the branch-to-environment mapping.

| Environment | Resource group | Deploys on | Reviewer |
|---|---|---|---|
| `dev` | `rg-pokedex-dev` | Push to `develop` | None |
| `itg` | `rg-pokedex-itg` | Push to `release/**` | Optional, set in GitHub |
| `identity` | Chosen at run time | Manual `identity.yml` run | Required |

## Resources per environment

| Resource | Name pattern | Created by |
|---|---|---|
| Log Analytics | `log-pokedex-<env>` | `main.bicep` |
| Application Insights | `appi-pokedex-<env>` | `main.bicep` |
| Container Registry | `crpokedex<env><suffix>` | `main.bicep` |
| Key Vault | `kv-pokedex-<env>-<suffix>` | `main.bicep` |
| Container Apps environment | `cae-pokedex-<env>` | `main.bicep` |
| Storage (ADLS Gen2) | `stpokedex<env><suffix>` | `main.bicep` |
| Function App | `func-pokedex-<env>-<suffix>` | `main.bicep` |
| Container App (agent, internal) | `ca-agent-pokedex-<env>` | `main.bicep` |
| Container App (backend, external) | `ca-backend-pokedex-<env>` | `main.bicep` |
| Static Web App | `swa-pokedex-<env>-<suffix>` | `main.bicep` |
| Managed identities | `id-agent-`, `id-functions-`, `id-backend-` + `pokedex-<env>` | `main.bicep` |

`<suffix>` is the `uniqueSuffix` in `parameters/<env>.bicepparam`. Choose it once. Changing it creates new resources and orphans the old ones.

## Settings set by CD, not by Bicep

The Container Apps receive their application settings from the GitHub environment during deployment. Bicep only creates the apps. See each repository's `docs/ENVIRONMENTS.md`.

## Not yet provisioned

- Event Grid subscriptions for blob-created events (the data pipeline's event triggers). Create them after the Function App deploys.
- Production environment. Add only after a human decides how `itg` promotes to production.
