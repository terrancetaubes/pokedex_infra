# Security policy

## Reporting a vulnerability

Do not open a public issue. Contact the repository owner directly through a private channel.

## Security rules for this repository

- No secrets, keys, certificates, or connection strings in code, parameters, or workflow files.
- Authentication from GitHub Actions to Azure uses OpenID Connect (OIDC) federated credentials only.
- Role assignments follow least privilege. Role scopes are resource groups, not subscriptions.
- The `identity-prod` environment requires a human approval before any IAM change.
- Pull requests from forks do not receive Azure credentials. Keep `pull_request` workflows free of secrets.
