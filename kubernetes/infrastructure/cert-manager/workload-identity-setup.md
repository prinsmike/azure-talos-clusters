# Workload Identity Setup for cert-manager

This guide configures cert-manager to use Azure Workload Identity for DNS-01
challenges on the **public** DNS zone (`example.com`).

## Prerequisites

- Talos cluster with OIDC issuer configured (see [Talos OIDC Guide](https://www.talos.dev/latest/kubernetes-guides/configuration/oidc-issuer/))
- Public DNS zone configured in `environments/prod/network-and-security/`
- cert-manager installed in the cluster

## Terraform-Based Setup (Recommended)

The managed identity and role assignments are managed via Terraform across two layers:

### Layer: network-and-security (Managed Identity + Role Assignment)

Enable the cert-manager identity in `environments/prod/network-and-security/`:

```bash
cd environments/prod/network-and-security

terraform apply \
  -var="azure_subscription_id=<sub-id>" \
  -var="enable_cert_manager_identity=true"
```

This creates:
- Managed identity: `id-cert-manager-prod`
- DNS Zone Contributor role assignment on the public DNS zones

Get the client ID for ClusterIssuer configuration:

```bash
terraform output cert_manager_identity_client_id
```

### Layer: talos-cluster (Federated Credential)

After configuring the OIDC issuer in your Talos cluster, enable federation in
`environments/prod/talos-cluster/`:

```bash
cd environments/prod/talos-cluster

terraform apply \
  -var="azure_subscription_id=<sub-id>" \
  -var="enable_cert_manager_federation=true" \
  -var="oidc_issuer_url=https://your-oidc-issuer-url"
```

The OIDC issuer URL depends on your setup. Common patterns:
- Azure Blob Storage: `https://<storage-account>.blob.core.windows.net/<container>`
- GitHub Pages: `https://<org>.github.io/<repo>`

## Kubernetes Configuration

### 1. Annotate cert-manager Service Account

```bash
CLIENT_ID=$(cd environments/prod/network-and-security && terraform output -raw cert_manager_identity_client_id)

kubectl annotate serviceaccount cert-manager \
  --namespace cert-manager \
  azure.workload.identity/client-id=$CLIENT_ID
```

### 2. Update ClusterIssuer

Configure the ClusterIssuer to use workload identity in `cluster-issuers.yaml`:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod-account-key
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

### 3. Restart cert-manager

```bash
kubectl rollout restart deployment cert-manager -n cert-manager
```

## Verification

```bash
# Create a test certificate
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: test-cert
  namespace: default
spec:
  secretName: test-cert-tls
  issuerRef:
    name: letsencrypt-staging
    kind: ClusterIssuer
  dnsNames:
    - test.example.com
EOF

# Watch the certificate
kubectl get certificate test-cert -w

# Check challenges
kubectl get challenges -A

# Clean up test
kubectl delete certificate test-cert
kubectl delete secret test-cert-tls
```

## Troubleshooting

```bash
# Check cert-manager can authenticate
kubectl logs -n cert-manager -l app=cert-manager | grep -i azure

# Verify identity binding
kubectl describe sa cert-manager -n cert-manager

# Check if TXT record was created
az network dns record-set txt list \
  --zone-name example.com \
  --resource-group rg-talos-prod-network-eastus \
  --query "[?contains(name, '_acme-challenge')]"
```

## Manual Setup (Legacy)

If you prefer to create resources manually via Azure CLI, use the following commands:

### 1. Create Managed Identity

```bash
RESOURCE_GROUP="rg-talos-prod-network-eastus"
IDENTITY_NAME="id-cert-manager-prod"

az identity create \
  --name $IDENTITY_NAME \
  --resource-group $RESOURCE_GROUP

IDENTITY_CLIENT_ID=$(az identity show \
  --name $IDENTITY_NAME \
  --resource-group $RESOURCE_GROUP \
  --query clientId -o tsv)

IDENTITY_PRINCIPAL_ID=$(az identity show \
  --name $IDENTITY_NAME \
  --resource-group $RESOURCE_GROUP \
  --query principalId -o tsv)
```

### 2. Grant DNS Zone Contributor Role

```bash
DNS_ZONE_NAME="example.com"
DNS_ZONE_RESOURCE_GROUP="rg-talos-prod-network-eastus"

DNS_ZONE_ID=$(az network dns zone show \
  --name $DNS_ZONE_NAME \
  --resource-group $DNS_ZONE_RESOURCE_GROUP \
  --query id -o tsv)

az role assignment create \
  --assignee $IDENTITY_PRINCIPAL_ID \
  --role "DNS Zone Contributor" \
  --scope $DNS_ZONE_ID
```

### 3. Configure Federated Credential

```bash
OIDC_ISSUER="https://your-oidc-issuer-url"

az identity federated-credential create \
  --name cert-manager-federated \
  --identity-name $IDENTITY_NAME \
  --resource-group $RESOURCE_GROUP \
  --issuer $OIDC_ISSUER \
  --subject "system:serviceaccount:cert-manager:cert-manager" \
  --audiences "api://AzureADTokenExchange"
```
