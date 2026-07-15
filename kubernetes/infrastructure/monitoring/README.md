# Monitoring Stack for Talos Linux

kube-prometheus-stack deployment configured for Talos Linux on Azure.

## Prerequisites

- Kubernetes cluster running on Talos Linux
- Azure CSI driver installed with storage classes
- Helm 3.x installed

## Storage Classes

The monitoring stack uses Azure managed disks:

- **Dev**: `managed-csi-premium-lrs` (LRS - locally redundant)
- **Prod**: `managed-csi-premium-zrs` (ZRS - zone redundant)

Ensure these storage classes exist before deploying.

## Deployment

### Create Namespace

The monitoring namespace requires privileged pod security for node-exporter:

```bash
kubectl create namespace monitoring
kubectl label namespace monitoring pod-security.kubernetes.io/enforce=privileged
```

### Add Helm Repository

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

### Install - Dev Environment

```bash
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --version 66.3.1 \
  -f values-common.yaml \
  -f values-dev.yaml
```

### Install - Prod Environment

```bash
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --version 66.3.1 \
  -f values-common.yaml \
  -f values-prod.yaml
```

### Upgrade

```bash
helm upgrade kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  -f values-common.yaml \
  -f values-dev.yaml  # or values-prod.yaml
```

## Accessing Services

### Port Forward (Dev)

```bash
# Grafana
kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 -n monitoring

# Prometheus
kubectl port-forward svc/kube-prometheus-stack-prometheus 9090:9090 -n monitoring

# Alertmanager
kubectl port-forward svc/kube-prometheus-stack-alertmanager 9093:9093 -n monitoring
```

### Default Credentials

- **Grafana Dev**: admin / admin (change after first login)
- **Grafana Prod**: Use external secret management

## Talos Linux Considerations

### Disabled Components

The following components are disabled because they're not accessible on Talos Linux:

- `kubeControllerManager` - runs in container, metrics not exposed
- `kubeScheduler` - runs in container, metrics not exposed
- `kubeProxy` - replaced by Cilium
- `kubeEtcd` - etcd runs in container, use Talos metrics instead

### Node Exporter

Node exporter is configured with Talos-specific filesystem exclusions to avoid errors from the immutable filesystem.

### Tolerations

All monitoring components tolerate control plane taints to ensure metrics collection from all nodes.

## File Structure

```
monitoring/
├── README.md
├── example-values.yaml    # Reference configuration
├── values-common.yaml     # Shared Talos-specific settings
├── values-dev.yaml        # Dev: smaller storage, single replicas
└── values-prod.yaml       # Prod: HA, ZRS storage, longer retention
```

## Resource Summary

| Component | Dev | Prod |
|-----------|-----|------|
| Prometheus Replicas | 1 | 2 |
| Prometheus Storage | 20Gi LRS | 100Gi ZRS |
| Prometheus Retention | 7 days | 30 days |
| Alertmanager Replicas | 1 | 2 |
| Alertmanager Storage | 2Gi LRS | 5Gi ZRS |
| Grafana Replicas | 1 | 2 |
| Grafana Storage | 5Gi LRS | 10Gi ZRS |
