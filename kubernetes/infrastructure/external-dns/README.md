# external-dns — self-service internal DNS

external-dns gives developers a **no-PR path** to expose an app on the internal
network. It watches Kubernetes Services / Ingresses / HTTPRoutes and creates the
matching records in the **`apps.int.example.com`** private DNS zone automatically.

This is change **C** of the platform design — see
[`docs/adr/0008-dns-delegated-self-service.md`](../../../docs/adr/0008-dns-delegated-self-service.md).

## Where the pieces live

| Piece | Layer | What it does |
|---|---|---|
| `apps.int.example.com` private zone | `network-and-security` (Terraform) | The zone external-dns writes into |
| `id-external-dns-{env}` UAMI + `DNS Zone Contributor` on the apps zone **only** | `network-and-security` (Terraform) | The security boundary (Azure RBAC) |
| Federated identity credential (SA → UAMI) | `talos-cluster` (Terraform) | Lets the pod exchange its SA token for the UAMI |
| This Helm release | `kubernetes/` (here) | Runs external-dns, scoped to the apps zone |

## Prerequisites

1. `enable_external_dns_identity = true` in the environment's `network-and-security`
   layer, and an `internal_apps_zone_name` set. Apply it.
2. The `talos-cluster` layer's `external-dns` federated credential enabled (binds
   `system:serviceaccount:external-dns:external-dns` to the UAMI).
3. Azure Workload Identity webhook installed in the cluster.
4. Fill in `values-{env}.yaml`:
   - `azure.subscriptionId`, `azure.tenantId`
   - `azure.resourceGroup` = the network-and-security RG (`rg-talos-{env}-network-{loc}`)
   - `serviceAccount.annotations.azure.workload.identity/client-id` =
     `terraform -chdir=environments/{env}/network-and-security output -raw external_dns_identity_client_id`

## Install

```bash
helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/
helm repo update

# dev
helm upgrade --install external-dns external-dns/external-dns \
  --namespace external-dns --create-namespace \
  -f values-common.yaml -f values-dev.yaml

# prod
helm upgrade --install external-dns external-dns/external-dns \
  --namespace external-dns --create-namespace \
  -f values-common.yaml -f values-prod.yaml
```

## Developer workflow — exposing an app (no PR)

Add a hostname under `apps.int.example.com` to your Service/Ingress/HTTPRoute:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp
  annotations:
    external-dns.alpha.kubernetes.io/hostname: myapp.apps.int.example.com
spec:
  type: LoadBalancer   # or an Ingress/HTTPRoute on the internal Cilium gateway
  # ...
```

external-dns creates `myapp.apps.int.example.com` automatically. Nothing under
`int.example.com` (apex) or the public zones can be created this way — those
require a PR to the security-owned `network-and-security` layer.

## TLS for internal apps

`apps.int.example.com` is a **private** zone, so Let's Encrypt DNS-01 (which needs
public resolution) cannot be used. Issue certs from the **internal-CA ClusterIssuer**
instead — see
[`../cert-manager/internal-ca-cluster-issuer.yaml`](../cert-manager/internal-ca-cluster-issuer.yaml).
Public apps on `example.com` keep using the cert-manager Let's Encrypt DNS-01 flow.

## Security notes

- The external-dns identity holds `DNS Zone Contributor` on `apps.int.example.com`
  **only** — even if the pod is compromised it cannot touch the apex or public zones.
- `domainFilters` and the TXT ownership registry are additional guardrails.
- Optionally add a policy engine (Kyverno/Gatekeeper) to restrict each team to
  `*.<team>.apps.int.example.com` — noted in `docs/ROADMAP.md`.
