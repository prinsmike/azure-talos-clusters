# Gateway API Configuration

Gateway API is the next-generation Kubernetes API for managing traffic routing.
It provides more expressive, extensible, and role-oriented interfaces compared to
the Ingress API.

Two gateways are provided:

| Gateway | Domain | TLS issuer | Exposure |
|---------|--------|-----------|----------|
| `cilium-gateway-internal` | `*.apps.int.example.com` | `internal-ca` (in-cluster CA) | Internal LB (private access) |
| `cilium-gateway-public` | `*.example.com` | `letsencrypt-prod` (DNS-01) | vWAN firewall DNAT |

The public zone is resolvable on the internet, so it uses Let's Encrypt. The
internal apps zone is private, so it uses the in-cluster CA - see
[ADR-0008](../../../docs/adr/0008-dns-delegated-self-service.md).

## Prerequisites

- Cilium 1.16+ with Gateway API enabled
- cert-manager for TLS certificate management (internal-ca and/or letsencrypt-prod)

## Installation

### 1. Install Gateway API CRDs

```bash
# Install standard Gateway API CRDs (v1.2.0)
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_gatewayclasses.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_gateways.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_httproutes.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_referencegrants.yaml
```

Or use the provided script:

```bash
./install-crds.sh
```

### 2. Enable Gateway API in Cilium

Upgrade Cilium with Gateway API enabled:

```bash
helm upgrade cilium cilium/cilium --version 1.16.3 \
  --namespace kube-system \
  -f ../cilium/values-common.yaml \
  -f ../cilium/values-dev.yaml \
  --set gatewayAPI.enabled=true
```

Verify the GatewayClass is created:

```bash
kubectl get gatewayclasses
# Should show: cilium
```

### 3. Deploy Gateway and Routes

Internal apps gateway:

```bash
kubectl apply -f gateway-internal.yaml
kubectl apply -f httproutes-internal.yaml
```

Public gateway (optional, requires vWAN firewall DNAT + public DNS):

```bash
kubectl apply -f gateway-public.yaml
```

## Architecture

```
                    ┌─────────────────────────────────────────────────┐
                    │               Gateway (HTTPS :443)              │
                    │         cilium-gateway-internal                 │
                    │         IP: 10.100.2.x (Internal LB)            │
                    └─────────────────────────────────────────────────┘
                                          │
           ┌──────────────────────────────┼──────────────────────────────┐
           │                              │                              │
           ▼                              ▼                              ▼
   ┌───────────────┐            ┌───────────────┐            ┌───────────────┐
   │  HTTPRoute    │            │  HTTPRoute    │            │  HTTPRoute    │
   │  grafana      │            │  prometheus   │            │  alertmanager │
   └───────────────┘            └───────────────┘            └───────────────┘
           │                              │                              │
           ▼                              ▼                              ▼
   ┌───────────────┐            ┌───────────────┐            ┌───────────────┐
   │  Service      │            │  Service      │            │  Service      │
   │  grafana:80   │            │  prometheus   │            │  alertmanager │
   └───────────────┘            └───────────────┘            └───────────────┘
```

## HTTPS Enforcement

Each Gateway is configured to:

1. **Listen on HTTPS (443)** - Primary listener with TLS termination
2. **HTTP to HTTPS Redirect** - HTTP (80) requests are automatically redirected to HTTPS

TLS certificates are managed by cert-manager: the internal gateway uses the
`internal-ca` ClusterIssuer, the public gateway uses `letsencrypt-prod`.

## Files

| File | Description |
|------|-------------|
| `install-crds.sh` | Script to install Gateway API CRDs |
| `gateway-internal.yaml` | Internal apps gateway (`*.apps.int.example.com`, internal CA) |
| `httproutes-internal.yaml` | HTTPRoutes for monitoring / echo services on the internal gateway |
| `gateway-public.yaml` | Public gateway (`*.example.com`, Let's Encrypt) |

## Troubleshooting

### Check Gateway status

```bash
kubectl get gateway -n kube-system
kubectl describe gateway cilium-gateway-internal -n kube-system
```

### Check HTTPRoute status

```bash
kubectl get httproutes -A
kubectl describe httproute grafana -n monitoring
```

### Verify Cilium Gateway API support

```bash
kubectl get gatewayclasses
kubectl exec -n kube-system -it ds/cilium -- cilium status | grep Gateway
```

### Check certificate status

```bash
kubectl get certificates -A
kubectl describe certificate internal-gateway-tls -n kube-system
```
