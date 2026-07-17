# ADR-0006: vWAN Hub-Spoke Connectivity for Centralized Routing

## Status

Accepted

## Date

2025-12-11

## Context

We need to connect our Talos Kubernetes infrastructure to a central management
Virtual WAN (vWAN) in production for centralized connectivity, security inspection,
and routing — and a way to test that integration before connecting production
workloads.

Our layered architecture:
- **management**: shared resources (state storage, ACR, Key Vault, optional vWAN)
- **network-and-security**: per-environment networking (VNet, NSGs, NAT Gateway)
- **talos-cluster**: Talos cluster resources (VMSS, Load Balancer)

Current network layout:
- Dev: VNet `10.100.0.0/16`
- Prod: VNet `10.200.0.0/16`
- Central management vWAN Hub: existing infrastructure owned by the central network
  team

Key requirements:
1. Connect the production environment to the existing central vWAN.
2. Test vWAN integration without affecting production.
3. Keep it optional (not every environment needs vWAN).
4. Support cross-subscription connectivity.

## Decision

Implement a two-part vWAN solution:

1. **Optional test vWAN in the management layer**: a vWAN with Azure Firewall in the
   management subscription for validating connectivity before production.
2. **Optional vWAN connection in network-and-security**: VNet-to-Hub connection
   capability per environment.

```
┌─────────────────────────────────────────────────────────────────┐
│                    Management Subscription                       │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │          vWAN Hub (test or central)                        │  │
│  │  ┌─────────────────────────────────────────────────────┐  │  │
│  │  │               Azure Firewall (Secured Hub)           │  │  │
│  │  └─────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────┘  │
│                              │ Virtual Hub Connection             │
└──────────────────────────────┼───────────────────────────────────┘
          ┌────────────────────┴────────────────────┐
          ▼                                          ▼
┌─────────────────────┐               ┌─────────────────────┐
│   Dev Subscription  │               │  Prod Subscription  │
│  VNet 10.100.0.0/16 │               │  VNet 10.200.0.0/16 │
└─────────────────────┘               └─────────────────────┘
```

```
modules/
├── vwan/                    # vWAN + Hub + Firewall
└── vwan-connection/         # VNet to Hub connection

management/vwan.tf           # optional test vWAN
environments/*/network-and-security/vwan.tf   # optional connection
```

## Rationale

### Why optional deployment

- **Testing flexibility**: validate configuration on a test vWAN before production.
- **Cost management**: vWAN + Azure Firewall is expensive (~$900/month); deploy only
  when needed.
- **Backward compatibility**: existing deployments work without vWAN.

### Why the management layer for the test vWAN

- **Mirrors production**: the central vWAN lives in the management subscription; the
  test vWAN follows the same pattern.
- **Centralized firewall policy**: managed in one place.
- **Cross-subscription support**: environments connect from different subscriptions.

### Why network-and-security for connections

- **Network ownership**: this layer owns the VNet — the logical place for connections.
- **Independent lifecycle**: the connection changes without affecting the cluster.
- **Consistency**: Twingate and DNS are also configured here.

### Firewall policy baseline

The test vWAN firewall ships basic allow rules — HTTPS/HTTP, DNS, NTP, RFC1918
spoke-to-spoke, and application rules for Azure services, container registries, and
Kubernetes endpoints — a working baseline for testing while staying restrictive.

## Trade-offs

### Accepted

- **Higher cost when enabled**: Azure Firewall ~$900/month.
- **Deployment time**: vWAN Hub + Firewall takes 20–30 minutes.
- **Cross-subscription RBAC**: requires Network Contributor on the vWAN Hub resource
  group.

### Mitigated

- Features are disabled by default; simple boolean toggles control everything; the
  test vWAN can be destroyed after validation.

## Consequences

### Positive

- Production can connect to the existing central vWAN.
- A test environment is available for validating vWAN configuration.
- All features optional with sensible defaults.

### Negative

- Additional variables per environment.
- Must coordinate with the central network team for the production vWAN Hub ID.
- Firewall rules may need adjustment for specific workloads.

### Neutral

- NAT Gateway keeps working when vWAN is disabled.
- When vWAN internet security is enabled, egress routes through the firewall instead
  of the NAT Gateway.

## Configuration

```hcl
# management — test vWAN
enable_vwan             = true
vwan_hub_address_prefix = "10.250.0.0/23"
vwan_firewall_sku       = "Standard"

# network-and-security — connection
enable_vwan_connection         = true
vwan_hub_id                    = "<vwan-hub-resource-id>"
vwan_internet_security_enabled = true
```

## References

- [Azure Virtual WAN](https://learn.microsoft.com/en-us/azure/virtual-wan/)
- [Secured Virtual Hub](https://learn.microsoft.com/en-us/azure/firewall-manager/secured-virtual-hub)
- [Virtual Hub Routing](https://learn.microsoft.com/en-us/azure/virtual-wan/about-virtual-hub-routing)
