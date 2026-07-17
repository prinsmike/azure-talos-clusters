# ADR-0001: Deploy Twingate Connectors Per Environment

## Status

Accepted

## Date

2025-11-29

## Context

We need private, zero-trust remote access to our Talos Kubernetes clusters on Azure
without exposing management endpoints (the Talos API, the Kubernetes API, internal
services) to the internet. Twingate is the chosen private-access solution. There are
two ways to place its connectors:

1. **Per-environment connectors**: deploy connectors inside each environment's VNet
   (dev and prod separately).
2. **Shared management network**: deploy a dedicated management VNet with connectors
   peered to every environment.

Our infrastructure uses a layered architecture with explicit isolation between
environments. Layers reference each other via Azure data sources rather than
Terraform remote state, enabling independent lifecycle management.

Current network layout:
- Dev: VNet `10.100.0.0/16`
- Prod: VNet `10.200.0.0/16`

## Decision

Deploy Twingate connectors within each environment's **network-and-security** layer,
rather than creating a shared management network.

```
environments/
├── dev/
│   └── network-and-security/
│       └── twingate.tf
└── prod/
    └── network-and-security/
        └── twingate.tf
```

## Rationale

### Security Isolation

- **Blast-radius limitation**: a compromised connector in dev cannot be used to reach
  prod resources.
- **Zero-trust alignment**: each environment keeps its own security boundary.
- **No cross-environment coupling**: avoids the network-level coupling between
  environments that our Terraform architecture deliberately avoids.

### Architectural Consistency

- **Independent lifecycle**: connectors can be upgraded, tested, or replaced
  per-environment without affecting others.
- **Data-source pattern**: continues our pattern of referencing resources via Azure
  data sources rather than cross-environment dependencies.
- **Same VNet as protected resources**: no VNet peering required.

### Trade-offs Accepted

- **More connectors to manage**: 2+ per environment for HA (4+ total vs 2+ shared).
- **Higher infrastructure cost**: additional VM resources per environment.
- **Configuration duplication**: mitigated by a shared connector module.

## Consequences

### Positive

- Maintains security isolation between environments.
- Aligns with existing architectural patterns.
- Enables independent maintenance windows per environment.
- Simplifies NSG rules (no cross-VNet traffic).

### Negative

- Increased connector count and associated cost.
- Must remember to apply connector updates to both environments.

### Neutral

- The Twingate provider is configured in the network-and-security layer.
- Each environment needs its own Twingate remote network and connectors in the
  Twingate admin console.

## Implementation

The shared module `modules/twingate-connector-vm/`:

- Creates the Twingate remote network and connector resources via the Twingate
  provider.
- Runs each connector as a lightweight Azure **B-series VM** (cost-efficient) in a
  dedicated connectors subnet per environment.

| Environment | Connector Subnet | Suggested VM Size |
|-------------|------------------|-------------------|
| Dev | `10.100.4.0/24` | `Standard_B1ls` |
| Prod | `10.200.4.0/24` | `Standard_B1s` |

Twingate is disabled by default. To enable (secrets can come from the Operations Key
Vault — see [ADR-0003](0003-operations-key-vault-for-secrets.md)):

```hcl
# terraform.tfvars
enable_twingate          = true
twingate_connector_count = 2   # 2+ for HA
```

### Files

- `modules/twingate-connector-vm/` — shared connector module (VM-based).
- `environments/*/network-and-security/twingate.tf` — module instantiation.
- `environments/*/network-and-security/{providers,variables,network,outputs}.tf` —
  provider, variables, connector subnet/NSG, and outputs.

## References

- [Twingate Terraform Provider](https://registry.terraform.io/providers/Twingate/twingate/latest/docs)
- [Twingate Connector Deployment](https://docs.twingate.com/docs/connectors)
