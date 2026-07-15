# Cilium CNI with Ingress Controller

Cilium provides both CNI networking and ingress controller functionality.

## Installation

```bash
helm repo add cilium https://helm.cilium.io/
helm repo update
```

### Dev Environment

```bash
helm install cilium cilium/cilium --version 1.16.3 \
  --namespace kube-system \
  -f values-common.yaml \
  -f values-dev.yaml
```

### Prod Environment

```bash
helm install cilium cilium/cilium --version 1.16.3 \
  --namespace kube-system \
  -f values-common.yaml \
  -f values-prod.yaml
```

## Key Settings

| Setting | Value | Purpose |
|---------|-------|---------|
| `kubeProxyReplacement` | `true` | Cilium replaces kube-proxy |
| `k8sServiceHost` | `localhost` | Uses KubePrism (Talos local API proxy) |
| `k8sServicePort` | `7445` | KubePrism port |
| `ingressController.enabled` | `true` | Enable Cilium Ingress |
| `ingressController.loadbalancerMode` | `shared` | Single LB for all ingresses |

## Ingress Configuration

### Load Balancer

Both environments use internal Azure Load Balancers:

- **Dev**: Internal LB accessible via Twingate (10.100.2.x)
- **Prod**: Internal LB with traffic routed through vWAN firewall (10.200.2.x)

To set a specific IP, uncomment `loadBalancerIP` in the environment values file.

### Creating an Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  annotations:
    # Use cert-manager for TLS
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: cilium
  tls:
    - hosts:
        - app.example.com
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

## Upgrading

```bash
# Dev
helm upgrade cilium cilium/cilium --version 1.16.3 \
  --namespace kube-system \
  -f values-common.yaml \
  -f values-dev.yaml

# Prod
helm upgrade cilium cilium/cilium --version 1.16.3 \
  --namespace kube-system \
  -f values-common.yaml \
  -f values-prod.yaml
```

## Verification

```bash
# Check Cilium status
cilium status

# Check ingress controller
kubectl get svc -n kube-system cilium-ingress

# List ingresses
kubectl get ingress -A
```

## Hubble UI

Hubble provides network observability. Access via port-forward:

```bash
kubectl port-forward -n kube-system svc/hubble-ui 12000:80
# Open http://localhost:12000
```
