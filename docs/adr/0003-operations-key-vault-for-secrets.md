# ADR-0003: Operations Key Vault for Centralized Secret Management

## Status

Accepted

## Date

2025-11-30

## Context

When deploying with Terraform, sensitive values like API tokens must be provided at
apply time. Passing them via CLI variables:

```bash
terraform apply -var="twingate_api_token=<token>"
```

has several drawbacks:

1. **Shell history exposure**: secrets land in `~/.bash_history`.
2. **CI/CD log leakage**: risk of secrets appearing in build logs.
3. **No central management**: every operator needs the raw secrets.
4. **No audit trail**: no visibility into who read a secret and when.
5. **Manual handling**: secrets copied/pasted for each apply.

Our layered architecture already uses per-environment Key Vaults (in the
network-and-security layer) for cluster-specific secrets like Talos configs. But
**operational** secrets that span environments (API tokens, shared credentials) had
no dedicated home.

## Decision

Create an **Operations Key Vault** in the **management** layer to store operational
secrets shared across environments.

```
┌─────────────────────────────────────────────────────────────┐
│ Management layer                                            │
│ ┌─────────────────────┐  ┌───────────────────────────────┐ │
│ │ Storage Account     │  │ Operations Key Vault          │ │
│ │ (tfstate)           │  │ (kv-talos-ops)                │ │
│ │                     │  │  - twingate-api-token         │ │
│ │                     │  │  - twingate-network           │ │
│ │                     │  │  - <future operational secrets>│ │
│ └─────────────────────┘  └───────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                                    │
                                    ▼ (data-source lookup)
┌─────────────────────────────────────────────────────────────┐
│ network-and-security (dev / prod)                          │
│   data "azurerm_key_vault_secret" "twingate_api_token" {}  │
└─────────────────────────────────────────────────────────────┘
```

### Key Vault configuration

- **Name**: `kv-talos-ops` (configurable)
- **Location**: same as other management resources (`rg-talos-ops`)
- **Authorization**: RBAC-based (no access policies)
- **Soft delete**: enabled; purge protection configurable

### Secret naming convention

`<service>-<credential-type>`, e.g. `twingate-api-token`, `twingate-network`.

## Rationale

### Why the management layer?

- **Shared across environments**: both dev and prod need the same operational secrets.
- **One-time setup**: secrets stored once, read by all environments.
- **Lifecycle alignment**: operational secrets outlive individual environment
  deployments.
- **No state coupling**: environments read via data sources, consistent with our
  architecture.

### Why RBAC authorization?

Simpler than access policies, integrates with Entra ID identities, supports granular
role assignments (Key Vault Secrets User vs Administrator), and follows Azure
security best practices.

### Backward compatibility

- **Default**: `use_operations_key_vault = false` (pass secrets by variable).
- **Opt-in**: set `use_operations_key_vault = true` to read from Key Vault.
- **Fail clearly**: if enabled but a secret is missing, Terraform errors.

## Consequences

### Positive

- No secrets in CLI/shell history or logs.
- Centralized management and a full audit trail (Key Vault logs all access).
- Secrets can be rotated without code changes.

### Negative

- Terraform apply now depends on Key Vault access.
- A one-time manual step to populate secrets.
- Small additional cost (~$0.03 / 10,000 operations).

## Implementation

**Management layer:**
- `management/operations-key-vault.tf` — Key Vault resource and RBAC
- `management/{variables,outputs}.tf`

**network-and-security (both environments):**
- `data.tf` — Key Vault and secret data sources
- `variables.tf` — `use_operations_key_vault`
- `providers.tf` — uses `local.*` for credentials

### One-time setup (after management apply)

```bash
az keyvault secret set --vault-name kv-talos-ops \
  --name twingate-api-token --value "<your-token>"
az keyvault secret set --vault-name kv-talos-ops \
  --name twingate-network --value "<your-network>"
```

## References

- [ADR-0001: Twingate Connectors Per Environment](0001-twingate-connectors-per-environment.md)
- [Azure Key Vault RBAC](https://learn.microsoft.com/en-us/azure/key-vault/general/rbac-guide)
- [Terraform azurerm_key_vault_secret data source](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_secret)
