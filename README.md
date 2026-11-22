# pokedex_infra

Azure infrastructure as code for the Pokedex platform. Bicep. Entra ID and RBAC are in `identity/`.

## Layout

| Path | Contents |
|---|---|
| `main.bicep` | One environment's platform. Calls the modules below. |
| `modules/` | Observability, platform (registry, Key Vault, Container Apps environment), data (ADLS Gen2 and queue), apps (Function App, Container Apps, Static Web App) |
| `parameters/` | `dev.bicepparam`, `itg.bicepparam` |
| `identity/` | Entra objects, RBAC, and the identity deployment for one environment |
| `.github/workflows/infra.yml` | CI on pull requests and branch pushes. CD to `dev` (develop) and `itg` (release/**) |
| `.github/workflows/identity.yml` | Manual identity deployment, with a reviewer |
| `docs/` | Environments, bootstrap, runbook |

## Local checks

```bash
az bicep lint --file main.bicep
az bicep lint --file identity/main.bicep
az deployment group what-if -g rg-pokedex-dev --parameters parameters/dev.bicepparam
```

See `AGENTS.md` for the rules and `../docs/BRANCHING_AND_RELEASE.md` for the release flow.
