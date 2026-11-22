# Bootstrap: first deployment

Run these steps once, in this order. Each step needs the output of the one before it.

Values for this tenant (tenant, subscription, GitHub owner, region, admin user) are in `docs/AZURE_ENVIRONMENT.md` in the parent folder.

## Automated: `scripts/bootstrap.ps1`

Run the script from the parent folder, after `az login` and `gh auth login`. It does the steps that need no portal work:

```powershell
az login --tenant 123cff06-a250-4e1c-b692-35a153e79643
gh auth login
.\scripts\bootstrap.ps1
```

The script covers: step 2 (identity app, federated credential, Graph permission, admin consent attempt), step 3 (resource groups), the admin guest invitation (writes the object ID into `identity/*.bicepparam`), and step 5a (GitHub environments, rulesets, default branch, and variables). It is safe to run again. It prints the steps that remain.

The script does not do these steps. Do them by hand:

- Step 2, part 2: the User Access Administrator role with its condition (below).
- Creating and pushing the five repositories.
- GitHub reviewers.
- Running the identity workflow, the platform deploy, and the Static Web Apps token.

`scripts/github_setup.sh` is the earlier bash version of the GitHub part. Use `bootstrap.ps1` instead.

## Prerequisites

1. Create five GitHub repositories with the folder names: `pokedex_infra`, `pokedex_data_functions`, `pokedex_agent_app`, `pokedex_backend`, `pokedex_ui`.
2. Push each folder to GitHub with a `develop` branch. Set `develop` as the default branch.
3. Run `scripts/bootstrap.ps1` (it sets the environments and rulesets for each repository that exists).
4. In GitHub, add a required reviewer to the `identity` environment in `pokedex_infra`, and to `itg` if you want one.

The GitHub owner is already set to `terrancetaubes` in `identity/dev.bicepparam` and `identity/itg.bicepparam`.

## Step 2: Create the identity pipeline's identity

Only this app is created by hand. The pipeline cannot create its own identity. `scripts/bootstrap.ps1` does part 1 of this step. The portal steps below are part 2.

```bash
az login
APP_ID=$(az ad app create --display-name gh-pokedex-identity --query appId -o tsv)
az ad sp create --id "$APP_ID"
az ad app federated-credential create --id "$APP_ID" --parameters '{
  "name": "github-env-identity",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:terrancetaubes/pokedex_infra:environment:identity",
  "audiences": ["api://AzureADTokenExchange"]
}'
echo "$APP_ID"
```

In the Azure portal:

1. Open the app. Under API permissions, add Microsoft Graph, application permission `Application.ReadWrite.All`. Click Grant admin consent. This needs a Global Administrator or Privileged Role Administrator.
2. Open Access control (IAM) on `rg-pokedex-dev` (created in step 3). Add a role assignment for `User Access Administrator`, assigned to `gh-pokedex-identity`. Add a condition that allows only these roles: Contributor, AcrPull, Storage Blob Data Owner, Storage Queue Data Contributor, Key Vault Secrets User.
3. Repeat step 2 on `rg-pokedex-itg`.

In GitHub, set these variables in the `identity` environment of `pokedex_infra`:

| Name | Value |
|---|---|
| `AZURE_TENANT_ID` | Your tenant ID (`az account show --query tenantId -o tsv`) |
| `AZURE_SUBSCRIPTION_ID` | Your subscription ID |
| `AZURE_IDENTITY_CLIENT_ID` | The `$APP_ID` value from above |

## Step 3: Create the resource groups

```bash
az group create --name rg-pokedex-dev --location eastus
az group create --name rg-pokedex-itg --location eastus
```

The identity pipeline and the platform both target these names.

## Step 4: Create the CI identities (stage 1)

This run creates the CI apps for every repository and environment, the API app, and the UI app. It also grants Contributor to the CI apps on their own resource group.

1. In `pokedex_infra`, open Actions, run `identity`, and choose `dev`. Approve the `identity` environment.
2. Run `identity` again and choose `itg`. Approve it.

Stage 1 uses a temporary redirect URI (`http://localhost:4280`) for the UI app. Step 5b replaces it.

Read the client IDs. You need them in step 5a:

```bash
az ad app list --display-name "gh-pokedex_infra-dev" --query "[0].appId" -o tsv
az ad app list --display-name "gh-pokedex_data_functions-dev" --query "[0].appId" -o tsv
az ad app list --display-name "gh-pokedex_agent_app-dev" --query "[0].appId" -o tsv
az ad app list --display-name "gh-pokedex_backend-dev" --query "[0].appId" -o tsv
az ad app list --display-name "gh-pokedex_ui-dev" --query "[0].appId" -o tsv
az ad app list --display-name "pokedex-ui-spa" --query "[0].appId" -o tsv
```

Repeat the five `gh-` lookups with `-itg`. `pokedex-ui-spa` is the sign-in app for the browser. It has one client ID for both environments.

The identity run also creates `pokedex-api` with two app roles: `admin` and `end-user`. Users get a role from `adminUserObjectIds` and `endUserObjectIds` in `identity/*.bicepparam`. `scripts/bootstrap.ps1` writes the admin user's object ID into those files. Add other users by object ID, then run `identity` again. The backend does not check the role claim yet.

## Step 5: Set the GitHub variables

Do this in two parts. Part A is needed before the platform deploys. Part B needs values that the platform creates.

### 5a. Before the platform deploy

For each environment (`dev`, `itg`), set these in each repository's environment of the same name:

| Name | Repositories | Value |
|---|---|---|
| `AZURE_TENANT_ID` | all four app repositories and `pokedex_infra` | Tenant ID |
| `AZURE_SUBSCRIPTION_ID` | all five | Subscription ID |
| `AZURE_CLIENT_ID` | all five | The CI app client ID for that repository and environment (from step 4) |
| `AZURE_RESOURCE_GROUP` | all five | `rg-pokedex-dev` or `rg-pokedex-itg` |

Then deploy the platform:

1. In `pokedex_infra`, edit `parameters/dev.bicepparam` if needed, then push to `develop`. This deploys `dev`.
2. Create a branch `release/1.0.0` from `develop` and push it. This deploys `itg`.

The platform creates the Container Registry, Container Apps, Function App, storage, Key Vault, and Static Web Apps.

### 5b. After the platform deploy

Look up the values the platform created:

```bash
# dev (repeat with -itg and rg-pokedex-itg)
az acr list -g rg-pokedex-dev --query "[0].name" -o tsv                       # AZURE_ACR_NAME
az functionapp list -g rg-pokedex-dev --query "[0].name" -o tsv              # AZURE_FUNCTIONAPP_NAME
az containerapp show -n ca-backend-pokedex-dev -g rg-pokedex-dev \
  --query properties.configuration.ingress.fqdn -o tsv                        # backend FQDN
az staticwebapp show -n swa-pokedex-dev-dev -g rg-pokedex-dev \
  --query defaultHostname -o tsv                                              # UI hostname
```

Set these variables in the matching environment:

| Repository | Variable | Value (dev example) |
|---|---|---|
| `pokedex_data_functions` | `AZURE_FUNCTIONAPP_NAME` | `func-pokedex-dev-dev` (from the lookup) |
| `pokedex_agent_app` | `AZURE_ACR_NAME` | `crpokedexdevdev` (from the lookup) |
| `pokedex_agent_app` | `AZURE_CONTAINERAPP_NAME` | `ca-agent-pokedex-dev` |
| `pokedex_agent_app` | `POKEDEX_MAX_TOOL_CALLS` | `5` |
| `pokedex_backend` | `AZURE_ACR_NAME` | `crpokedexdevdev` |
| `pokedex_backend` | `AZURE_CONTAINERAPP_NAME` | `ca-backend-pokedex-dev` |
| `pokedex_backend` | `AGENT_CONTAINERAPP_NAME` | `ca-agent-pokedex-dev` |
| `pokedex_backend` | `AGENT_APP_SCOPE` | `api://pokedex-agent/.default` (placeholder, see Open items) |
| `pokedex_backend` | `UI_ORIGIN` | `https://<UI hostname>` |
| `pokedex_ui` | `AZURE_TENANT_ID` | Tenant ID |
| `pokedex_ui` | `UI_CLIENT_ID` | `pokedex-ui-spa` client ID |
| `pokedex_ui` | `API_BASE_URL` | `https://<backend FQDN>` |
| `pokedex_ui` | `API_SCOPE` | `api://pokedex-api/access_as_user` |

The `itg` values follow the same pattern with `itg` in each name.

## Step 4 (stage 2): Grant workload access and set the UI redirect URIs

The workload identities can now be assigned roles, because their resources exist.

1. Edit `identity/dev.bicepparam` and `identity/itg.bicepparam`:
   - Replace `uiRedirectUris` with the two UI hostnames from step 5b, each as `https://<hostname>`.
   - Set `deployWorkloadRbac = true`.
2. Run `identity` for `dev`, then for `itg`.

Stage 2 grants AcrPull to the agent and backend identities. The Container Apps need it to pull the images that CD builds. Run stage 2 before the first application deploy.

## Step 6: Store the UI deployment token

The Static Web App token is the only stored secret in the platform.

```bash
az staticwebapp secrets list --name swa-pokedex-dev-dev --resource-group rg-pokedex-dev \
  --query "properties.apiKey" -o tsv
```

In `pokedex_ui`, add it as the environment secret `AZURE_STATIC_WEB_APPS_API_TOKEN` in `dev`. Repeat for `itg` with `swa-pokedex-itg-itg`. Do not paste the token into chat, a ticket, or a commit. Rotate it if it leaks.

## Step 7: Deploy the applications

Deploy in this order, because each service depends on the one before it:

1. `pokedex_data_functions`: push to `develop` (dev), then create `release/1.0.0` (itg).
2. `pokedex_agent_app`: same.
3. `pokedex_backend`: same. Its deploy reads the agent's URL.
4. `pokedex_ui`: same. Its build reads the backend URL.

Create Event Grid subscriptions for the data pipeline after step 1 (see `pokedex_data_functions/docs/ENVIRONMENTS.md`).

## Open items

- `AGENT_APP_SCOPE` is a placeholder. The backend cannot get a token for the agent until an app registration `pokedex-agent` exists and the agent validates tokens. Until then the backend returns 502 for chat requests.
- The Microsoft Graph Bicep extension is in preview. Pin its version in `bicepconfig.json`.
- These steps have not been run end to end. Expect small fixes on the first run.
