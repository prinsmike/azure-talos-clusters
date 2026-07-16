# Azure Resource Tagging Standards

## Overview

This document defines the tagging standards for all Azure resources in this project.
Consistent tagging enables cost tracking, resource management, and operational
excellence.

## Tag Naming Convention

**Use PascalCase for all tag keys** (first letter of each word capitalized, no spaces
or separators).

### ✅ Correct

```hcl
tags = {
  Project     = "talos-platform"
  Environment = "production"
  ManagedBy   = "terraform"
  Layer       = "network-and-security"
  Owner       = "platform-team"
  CostCenter  = "platform-ops"
}
```

### ❌ Incorrect

```hcl
# Don't use lowercase, snake_case, or kebab-case for keys
tags = {
  project     = "talos-platform"       # Wrong (lowercase)
  cost_center = "platform-ops"         # Wrong (snake_case)
  managed-by  = "terraform"            # Wrong (kebab-case)
}
```

## Required Tags

All resources **MUST** include these tags:

| Tag Key | Description | Example Values |
|---------|-------------|----------------|
| `Project` | Project identifier | `talos-platform` |
| `Environment` | Environment name | `production`, `staging`, `dev` |
| `ManagedBy` | Management tool | `terraform`, `manual` |
| `Owner` | Team responsible | `platform-team`, `security-team` |

## Standard Optional Tags

Resources **SHOULD** include these when applicable:

| Tag Key | Description | Example Values |
|---------|-------------|----------------|
| `Layer` | Infrastructure layer | `management`, `network-and-security`, `talos-cluster` |
| `CostCenter` | Cost allocation | `platform-ops`, `infrastructure` |
| `Component` | Component type | `networking`, `security`, `compute`, `storage` |
| `Workload` | Workload type | `platform`, `monitoring`, `ingress` |
| `Criticality` | Service criticality | `critical`, `high`, `medium`, `low` |
| `DataClassification` | Data sensitivity | `public`, `internal`, `confidential` |
| `BackupPolicy` | Backup requirement | `daily`, `weekly`, `none` |
| `DisasterRecovery` | DR requirement | `required`, `optional`, `none` |

## Tag Value Guidelines

- Use lowercase with hyphens for multi-word values.
- Keep values concise but descriptive.
- Avoid special characters except hyphens.
- Maximum length: 256 characters.

```hcl
tags = {
  Environment = "production"           # Good
  Component   = "network-security"     # Good
  Component   = "NetworkSecurity"      # Avoid (use lowercase-with-hyphens)
}
```

## Layer-Specific Tags

### Management

```hcl
tags = {
  Project     = "talos-platform"
  Environment = "shared"
  ManagedBy   = "terraform"
  Layer       = "management"
  Owner       = "platform-team"
  CostCenter  = "platform-ops"
  Component   = "shared-services"
}
```

### Network-and-Security

```hcl
tags = {
  Project     = "talos-platform"
  Environment = "production"
  ManagedBy   = "terraform"
  Layer       = "network-and-security"
  Owner       = "security-team"
  CostCenter  = "platform-ops"
  Component   = "networking"   # or "security"
}
```

### Talos Cluster

```hcl
tags = {
  Project     = "talos-platform"
  Environment = "production"
  ManagedBy   = "terraform"
  Layer       = "talos-cluster"
  Owner       = "platform-team"
  CostCenter  = "platform-ops"
  Component   = "compute"      # or "load-balancer", "storage"
}
```

## Implementation in Terraform

### Module-Level Tags

Define common tags with `locals` and merge resource-specific ones:

```hcl
locals {
  common_tags = merge(
    var.tags,
    {
      Layer     = "network-and-security"
      Component = "security"
    }
  )
}

resource "azurerm_key_vault" "example" {
  name                = "kv-example"
  location            = var.location
  resource_group_name = azurerm_resource_group.example.name
  tags                = local.common_tags
}
```

### Environment-Level Tags

Define base tags in `terraform.tfvars`:

```hcl
tags = {
  Project     = "talos-platform"
  Environment = "production"
  ManagedBy   = "terraform"
  CostCenter  = "platform-ops"
}
```

### Variable Definition

```hcl
variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
```

## Cost Allocation

For cost tracking and chargeback, always include `CostCenter`, `Project`, and
`Environment`; add `Workload` for workload-level breakdowns.

```bash
# Cost by Project
az consumption usage list \
  --query "[?tags.Project=='talos-platform'].{cost:pretaxCost}" \
  --output table

# Cost by Layer
az consumption usage list \
  --query "[?tags.Layer=='talos-cluster'].{cost:pretaxCost}" \
  --output table
```

## Tag Validation

### Pre-Deployment Checklist

- [ ] All required tags are present
- [ ] Tag keys use PascalCase
- [ ] Tag values use lowercase-with-hyphens
- [ ] No duplicate tags with different casing
- [ ] Tags are consistent across related resources

### Azure Policy (recommended)

Consider enforcing tagging with Azure Policy:

```json
{
  "policyRule": {
    "if": {
      "allOf": [
        { "field": "tags['Project']", "exists": "false" }
      ]
    },
    "then": { "effect": "deny" }
  }
}
```

## Common Pitfalls

### Case inconsistency

Azure treats tags as case-sensitive, so `Layer` and `layer` are **different** tags.
Always use PascalCase consistently to avoid accidental duplicates.

### Hardcoded values

```hcl
# ❌ Don't hardcode tags in resources
resource "azurerm_resource_group" "example" {
  tags = { Environment = "production" }
}

# ✅ Use variables and locals
resource "azurerm_resource_group" "example" {
  tags = var.tags
}
```

### Missing tag propagation

```hcl
# ✅ Always propagate tags across module boundaries
module "network" {
  source = "./modules/vnet"
  tags   = var.tags
}
```

## References

- [Azure Resource Tagging Best Practices](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-tagging)
- [Terraform azurerm Tagging Guide](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/tagging)
- [README.md](README.md) — project overview
