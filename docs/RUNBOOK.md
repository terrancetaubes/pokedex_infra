# Runbook

## A platform deployment fails

1. Open the failed run. Read the error in `az deployment group create`.
2. `AuthorizationFailed`: check that the GitHub environment's `AZURE_CLIENT_ID` is the CI app for that environment, and that the federated credential subject is `repo:<owner>@<ownerId>/pokedex_infra@<repoId>:environment:<env>` (numeric IDs, see `identity/*.bicepparam`). An `AADSTS700213` error means the subject does not match.
3. `InvalidTemplate` or a name conflict: check `parameters/<env>.bicepparam` and the unique suffix.
4. Roll back by reverting the commit on `develop` or on the `release/*` branch, then let CD run again. Do not delete resources by hand unless a human approves it.

## A role assignment is missing

Role assignments are in `identity/rbac.bicep`, and only `identity.yml` deploys them. Run `identity.yml` for the environment. Do not add assignments in the portal.

## Rotate or revoke a CI identity

1. Remove its federated credential in `identity/entra.bicep` and run `identity.yml`.
2. Confirm the GitHub environment variable no longer matches an active app.
3. Record the change in `PROJECT_CHANGELOG.md` and `AGENT_CHANGELOG.md`.
