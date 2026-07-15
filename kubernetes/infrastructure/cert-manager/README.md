# cert-manager with Azure DNS (DNS-01)

cert-manager automates TLS certificate management. For **public** apps
(`example.com`) it uses Let's Encrypt with DNS-01 challenges via Azure DNS.

> Internal apps on the private `apps.int.example.com` zone cannot use Let's
> Encrypt (DNS-01 needs public resolution). They get certificates from an
> in-cluster CA instead - see
> [`internal-ca-cluster-issuer.yaml`](internal-ca-cluster-issuer.yaml) and
> [ADR-0008](../../../docs/adr/0008-dns-delegated-self-service.md).

## Prerequisites

cert-manager needs permission to create TXT records in the public Azure DNS zone
for ACME challenges.

### Option A: Workload Identity via Terraform (Recommended)

The managed identity and role assignments are managed via Terraform. See
[workload-identity-setup.md](workload-identity-setup.md) for detailed instructions.

**Quick start:**
```bash
# network-and-security layer: create the managed identity + DNS Zone Contributor
# on the public zones.
cd environments/prod/network-and-security
terraform apply -var="enable_cert_manager_identity=true"

# talos-cluster layer: federate it to the cert-manager service account
# (after the cluster's OIDC issuer is configured).
cd environments/prod/talos-cluster
terraform apply -var="enable_cert_manager_federation=true" \
  -var="oidc_issuer_url=https://your-oidc-issuer"

# Annotate the service account with the identity's client ID.
CLIENT_ID=$(cd environments/prod/network-and-security && terraform output -raw cert_manager_identity_client_id)
kubectl annotate serviceaccount cert-manager -n cert-manager \
  azure.workload.identity/client-id=$CLIENT_ID
kubectl rollout restart deployment cert-manager -n cert-manager
```

See [ADR-0005](../../../docs/adr/0005-cert-manager-workload-identity.md) for the
architecture decision.

### Option B: Service Principal (Legacy)

1. Create a Service Principal
2. Grant "DNS Zone Contributor" role on the public DNS zone
3. Store credentials in a Kubernetes Secret

## Installation

```bash
# Add Jetstack Helm repo
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install cert-manager with CRDs
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.16.2 \
  --set crds.enabled=true
```

## Configure Azure DNS Access

### Using Service Principal

Create the secret with Azure credentials:

```bash
kubectl create secret generic azuredns-config \
  --namespace cert-manager \
  --from-literal=client-secret='<SERVICE_PRINCIPAL_PASSWORD>'
```

Update `cluster-issuers.yaml` with your values:
- `subscriptionID`: Your Azure subscription ID
- `resourceGroupName`: Resource group holding the public DNS zone (e.g. `rg-talos-prod-network-eastus`)
- `hostedZoneName`: Your public DNS zone (e.g. `example.com`)
- `tenantID`: Azure AD tenant ID
- `clientID`: Service Principal application (client) ID

### Using Workload Identity

See [workload-identity-setup.md](workload-identity-setup.md) for detailed
Terraform-based setup instructions.

Update `cluster-issuers.yaml` with the managed identity client ID:
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

## Apply Issuers

```bash
# Apply Let's Encrypt issuers with Azure DNS solver
kubectl apply -f cluster-issuers.yaml
```

This creates:
- `letsencrypt-staging` - For testing (fake certs, higher rate limits)
- `letsencrypt-prod` - For production (real certs)

## Usage

Add the annotation to your Ingress:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: cilium
  tls:
    - hosts:
        - app.example.com
        - "*.example.com"  # Wildcard supported with DNS-01!
      secretName: app-tls
  rules:
    - host: app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app
                port:
                  number: 80
```

## Wildcard Certificates

DNS-01 enables wildcard certificates. Create a Certificate resource:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: wildcard-example
  namespace: default
spec:
  secretName: wildcard-example-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  commonName: "*.example.com"
  dnsNames:
    - "example.com"
    - "*.example.com"
```

## Troubleshooting

```bash
# Check certificate status
kubectl get certificates -A

# Check certificate requests
kubectl get certificaterequests -A

# Check challenges (during issuance)
kubectl get challenges -A

# Describe a failing certificate
kubectl describe certificate <name> -n <namespace>

# View cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager

# Check DNS propagation
nslookup -type=TXT _acme-challenge.app.example.com
```

## Rate Limits

Let's Encrypt [rate limits](https://letsencrypt.org/docs/rate-limits/):
- 50 certificates per registered domain per week
- 5 duplicate certificates per week
- 300 new orders per account per 3 hours

Use `letsencrypt-staging` for testing to avoid hitting production limits.
