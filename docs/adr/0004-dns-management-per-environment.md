# ADR-0004: DNS Management Per Environment

## Status

**Superseded by [ADR-0008](0008-dns-delegated-self-service.md).**

> This ADR described the original DNS posture: each environment had a single DNS
> shape (dev = one private zone, prod = public zones), and every record — internal or
> public — was added by editing Terraform lists and opening a PR. ADR-0008 replaces
> this with a **three-zone model** (public, internal apex, internal apps) that keeps
> security-owned zones under Terraform review while letting developers self-serve
> ordinary internal app hostnames in-cluster (via external-dns) with no PR. The
> record still lives here for historical context.

## Date

2025-11-30

## Context

Engineers need to add DNS records for services running in the Talos clusters, and the
requirements differed by environment:

- **Dev**: internal DNS records for services reachable only over the private-access
  solution (private DNS).
- **Prod**: public DNS zones for external-facing services with nameserver delegation.

We wanted a solution that let engineers add records by modifying Terraform lists
(code-review workflow), gave the right visibility per environment, and fit the
layered architecture.

## Decision

Implement environment-specific DNS management in the network-and-security layer:

- **Dev**: an Azure Private DNS zone linked to the VNet, reachable only over the
  private-access solution.
- **Prod**: Azure Public DNS zones with nameserver outputs for external delegation.

A shared module at `modules/dns/` handles both private and public zones.

## Rationale

### List-based configuration

Following existing patterns (NSG rules, subnets, access policies), DNS records were
defined as lists:

```hcl
# Dev — internal services (private zone)
private_dns_a_records = [
  { name = "api", records = ["10.100.1.10"] },
  { name = "grafana", records = ["10.100.1.20"] },
]

# Prod — public zones with records
public_dns_zones = [
  {
    name = "example.com"
    a_records = [
      { name = "api", records = ["203.0.113.10"] },
    ]
  },
]
```

### Trade-offs accepted

- **Different patterns per environment**: dev used a single zone with record lists;
  prod used a zone list with nested records.
- **No cross-environment DNS**: dev and prod DNS were fully separate.
- **Manual registrar configuration**: prod nameservers had to be set at the registrar.

## Consequences

### Positive

- Engineers added DNS records via the standard PR workflow.
- Dev DNS was automatically private (VNet-linked).
- Prod nameservers were clearly output for registrar delegation.

### Negative (and why it was superseded)

- **Every** internal record required a Terraform PR — too slow for routine app
  hostnames, and it put ordinary app names in front of security reviewers
  unnecessarily.
- Different variable patterns between dev and prod caused confusion.

ADR-0008 keeps the security-owned zones and their PR gate, but adds a dedicated
developer-owned apps zone driven by external-dns so app hostnames need no PR.

## Implementation (historical)

```hcl
# Dev
private_dns_zone_name = "dev.int.example.com"
private_dns_a_records = [
  { name = "api", records = ["10.100.1.10"] },
]

# Prod
public_dns_zones = [
  {
    name = "example.com"
    a_records = [
      { name = "@", records = ["203.0.113.10"] },
      { name = "api", records = ["203.0.113.11"] },
    ]
    txt_records = [
      { name = "@", records = ["v=spf1 -all"] },
    ]
  },
]
```

After applying prod, configure the registrar with:

```bash
terraform output public_dns_zones_nameservers
```

## References

- Superseded by [ADR-0008: DNS — Security-Owned Zones with Delegated Self-Service](0008-dns-delegated-self-service.md)
- [Azure Private DNS](https://learn.microsoft.com/en-us/azure/dns/private-dns-overview)
- [Azure Public DNS](https://learn.microsoft.com/en-us/azure/dns/dns-overview)
