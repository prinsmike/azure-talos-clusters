# Ingress Examples

Example configurations for Cilium Ingress with cert-manager TLS on the **public**
zone (`example.com`).

> For **internal** apps on `apps.int.example.com`, you usually don't need an
> ingress example at all: set an `external-dns.alpha.kubernetes.io/hostname`
> annotation (or an Ingress host under the apps zone) and external-dns creates
> the DNS record automatically, with TLS from the internal CA. See
> [`../external-dns/`](../external-dns/) and
> [`../cert-manager/internal-ca-cluster-issuer.yaml`](../cert-manager/internal-ca-cluster-issuer.yaml).

## Files

| File | Description |
|------|-------------|
| `simple-ingress.yaml` | Basic ingress with automatic TLS certificate |
| `wildcard-certificate.yaml` | Wildcard cert for `*.example.com` |

## Quick Start

1. Update the examples with your domain and service details
2. Apply the configuration:

```bash
kubectl apply -f simple-ingress.yaml
```

3. Check certificate status:

```bash
kubectl get certificate
kubectl describe certificate example-app-tls
```

## Using Wildcard Certificates

For multiple services under the same domain, create a wildcard certificate once:

```bash
kubectl apply -f wildcard-certificate.yaml
```

Then reference it in your ingresses:

```yaml
spec:
  tls:
    - hosts:
        - api.example.com
      secretName: wildcard-example-tls  # Reuse the wildcard cert
```

## DNS Configuration

Remember to add DNS records for your ingress hosts.

**Internal apps (`apps.int.example.com`) - no PR, no Terraform**

external-dns creates the record for you when you set a hostname under the apps
zone on a Service / Ingress / HTTPRoute. See [`../external-dns/`](../external-dns/).

**Public apps (`example.com`) - security-owned, via Terraform**

Public records live in the `network-and-security` layer (peer-reviewed):

```hcl
# environments/prod/network-and-security/terraform.tfvars
public_dns_zones = [
  {
    name = "example.com"
    a_records = [
      { name = "app", records = ["<vwan-firewall-public-ip>"] },
    ]
  },
]
```

## Troubleshooting

```bash
# Check ingress status
kubectl get ingress
kubectl describe ingress example-app

# Check Cilium ingress service
kubectl get svc -n kube-system cilium-ingress

# Check certificate issuance
kubectl get challenges -A
kubectl logs -n cert-manager -l app=cert-manager
```
