# AGENTS.md: pokedex_infra

Read the parent `../AGENTS.md` first. Its rules apply here. The branch rules are in `../docs/BRANCHING_AND_RELEASE.md`.

## Purpose

All Azure resources for the Pokedex platform, for the `dev` and `itg` environments, and the Entra ID and RBAC that give workloads and CI access to them.

## Layout

| Path | Contents |
|---|---|
| `main.bicep` | One environment's platform. Resource-group scope. No role assignments. |
| `modules/` | Platform modules (see README) |
| `parameters/<env>.bicepparam` | Environment values. The unique suffix is set here. |
| `identity/entra.bicep` | CI apps per repository and environment, API app, UI app, identity app |
| `identity/rbac.bicep` | Role assignments for one environment |
| `identity/main.bicep` | Entry point for IAM. Run per environment |
| `identity/<env>.bicepparam` | IAM values for one environment |
| `.github/workflows/infra.yml` | CI and CD |
| `.github/workflows/identity.yml` | Manual IAM deployment |

## Rules for agents

- Put platform resources in `main.bicep` and `modules/`. Put every role assignment in `identity/rbac.bicep` only. Never add role assignments to the platform.
- Put every Entra object in `identity/entra.bicep`. Never create them in the portal.
- Keep the names in `identity/main.bicep` and `main.bicep` in step. Change both files together.
- Use the least role that works. Do not grant Owner, User Access Administrator, or subscription-wide roles.
- Parameters hold names and IDs only. No secrets.
- `identity.yml` is the only workflow that changes IAM.
- Run `az bicep lint` and `what-if` before you finish a change.
- Log every change in `AGENT_CHANGELOG.md`. Log cross-repository changes in `../PROJECT_CHANGELOG.md`.

## Open decisions

- Bicep is the IaC tool. Terraform is the alternative. A human decides before any change.
- Contributor is the CI role. Narrow it once the workloads are stable.
