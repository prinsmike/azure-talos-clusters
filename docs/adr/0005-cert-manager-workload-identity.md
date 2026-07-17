# ADR-0005: cert-manager Workload Identity for DNS-01 Challenges

## Status

Accepted

## Date

2025-12-01

## Context

cert-manager needs Azure credentials to create TXT records in Azure DNS for ACME
DNS-01 challenges. This enables:

- Automatic TLS provisioning via Let's Encrypt
- Wildcard certificates (only possible with DNS-01)
- Certificate issuance without exposing services to the internet

We needed a solution that follows Azure security best practices (no long-lived
credentials), fits the layered architecture, works on Talos Linux (no AKS-specific
features), and lets cert-manager manage TXT records in the **public** DNS zones.

## Decision

Use **Azure Workload Identity** to grant cert-manager access to the public DNS zones,
implemented across two Terraform layers:

**network-and-security:**
- A user-assigned managed identity for cert-manager (`id-cert-manager-{env}`)
- A `DNS Zone Contributor` role assignment on every public DNS zone

**talos-cluster:**
- A federated identity credential linking the managed identity to the Kubernetes
  service account (via the cluster's OIDC issuer)

```
environments/{env}/
├── network-and-security/
│   └── iam.tf                    # managed identity + DNS role
└── talos-cluster/
    └── workload-identity.tf      # federated credential
```

## Rationale

### Why workload identity over a service principal

| Aspect | Service Principal | Workload Identity |
|--------|-------------------|-------------------|
| Credentials | Client secret (password) | Federated token (no password) |
| Rotation | Manual | Automatic, none needed |
| Secret storage | K8s Secret / Key Vault | None |
| Azure recommendation | Legacy | Recommended |

### Why split across two layers

1. **Managed identity (network-and-security)**: lives with the DNS zones; the role
   assignment requires the zone resource in the same layer, and the identity's
   lifecycle is tied to infrastructure, not the cluster.
2. **Federated credential (talos-cluster)**: requires the OIDC issuer URL, which is
   only known after cluster bootstrap; it can be recreated with the cluster without
   touching the identity.

This preserves the principle of no cross-layer state dependencies while keeping
resources with their logical owners.

### Public zone only

Let's Encrypt validates DNS-01 against **public** DNS, so this identity is scoped to
the public zones. Internal apps on the private apps zone cannot use Let's Encrypt;
they get certificates from an in-cluster internal CA instead (see
[ADR-0008](0008-dns-delegated-self-service.md)). external-dns uses the **same
federation pattern** with a separate, apps-zone-scoped identity.

## Consequences

### Positive

- No long-lived secrets to manage or rotate.
- cert-manager manages DNS records for all public zones automatically.
- The role assignment automatically covers new public zones added to the list.

### Negative

- Requires an OIDC issuer configured in Talos (external dependency).
- Two applies needed (network-and-security first, then talos-cluster).
- The service-account annotation is a manual `kubectl` step.

## Implementation

### Enable in network-and-security

```bash
cd environments/prod/network-and-security
terraform apply \
  -var="azure_subscription_id=<sub-id>" \
  -var="enable_cert_manager_identity=true"
```

Creates the `id-cert-manager-prod` identity and a DNS Zone Contributor role on all
`public_dns_zones`.

### Enable in talos-cluster (after OIDC issuer is configured)

```bash
cd environments/prod/talos-cluster
terraform apply \
  -var="azure_subscription_id=<sub-id>" \
  -var="enable_cert_manager_federation=true" \
  -var="oidc_issuer_url=https://your-oidc-issuer"
```

### Configure cert-manager

```bash
CLIENT_ID=$(cd environments/prod/network-and-security && terraform output -raw cert_manager_identity_client_id)
kubectl annotate serviceaccount cert-manager -n cert-manager \
  azure.workload.identity/client-id=$CLIENT_ID
kubectl rollout restart deployment cert-manager -n cert-manager
```

### ClusterIssuer solver

```yaml
solvers:
  - dns01:
      azureDNS:
        subscriptionID: "<subscription-id>"
        resourceGroupName: "rg-talos-prod-network-eastus"
        hostedZoneName: "example.com"
        environment: AzurePublicCloud
        managedIdentity:
          clientID: "<cert_manager_identity_client_id>"
```

## References

- Mirrored (for the apps zone) by [ADR-0008](0008-dns-delegated-self-service.md).
- [Azure Workload Identity](https://learn.microsoft.com/en-us/azure/aks/workload-identity-overview)
- [cert-manager Azure DNS](https://cert-manager.io/docs/configuration/acme/dns01/azuredns/)
- [Talos OIDC Issuer](https://www.talos.dev/latest/kubernetes-guides/configuration/oidc-issuer/)
