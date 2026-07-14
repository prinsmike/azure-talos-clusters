# Management Layer

Creates the shared, cross-environment infrastructure that every other layer
depends on. Owned by the **Management** team (see `.github/CODEOWNERS`).

## Resources Created

- **Resource Group**: `rg-talos-ops` (var-driven)
- **Storage Account**: Terraform remote state with blob versioning and soft delete
- **Container Registry**: shared container images (dev, qa, prod)
- **Operations Key Vault**: operational secrets (e.g. Twingate API token) read by
  other layers via data sources
- **vWAN** (optional, `enable_vwan=true`): Virtual WAN + Secured Hub for testing
  central connectivity

> The shared **Talos image** (Azure Compute Gallery) is also published from this
> layer — added in a later step (`talos-image.tf`).

## Usage

This layer bootstraps its own state backend, so the first deployment uses local
state and then migrates to the storage account it just created:

```bash
# 1. Comment out the backend block in backend.tf
# 2. Initialize and apply with local state
terraform init
terraform apply

# 3. Uncomment the backend block in backend.tf
# 4. Migrate state to the remote backend
terraform init -migrate-state
```

### Variables

Copy `terraform.tfvars.example` to `terraform.tfvars` and set at least:

```hcl
azure_subscription_id   = "00000000-0000-0000-0000-000000000000"
storage_account_name    = "sttalosstate" # 3-24 lowercase alphanumeric, globally unique
container_registry_name = "acrtalos"     # 5-50 alphanumeric, globally unique
```

`storage_account_name` and `container_registry_name` are **globally unique** across
all of Azure — you must change them to values nobody else has taken.

## Outputs

Use the `backend_config_example` output to configure the other layers' backends:

```bash
terraform output backend_config_example
```
