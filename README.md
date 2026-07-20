# Azure Talos Clusters

**Turnkey [Talos Linux](https://www.talos.dev/) Kubernetes clusters on Azure, in Terraform.**

[![validate](https://github.com/prinsmike/azure-talos-clusters/actions/workflows/validate.yml/badge.svg)](https://github.com/prinsmike/azure-talos-clusters/actions/workflows/validate.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A clean, opinionated reference for running production-grade Talos Kubernetes clusters
on Azure VM Scale Sets — with a layered Terraform architecture, zero-trust private
access, a security-owned/developer-self-service DNS model, and a batteries-included
Kubernetes platform (Cilium, cert-manager, monitoring, storage).

Everything is optional-by-default and driven by variables, so you can start with a
single small dev cluster and grow into a multi-subscription, HA production estate
without rewriting anything.

## Highlights

- **Four clean layers**, coupled only by Azure name lookups — never Terraform remote
  state — so each layer applies independently.
- **Talos Linux**: immutable, API-managed, no SSH. Cilium replaces kube-proxy;
  KubePrism fronts the API at `localhost:7445`.
- **Shared Talos image** built once and published to an Azure Compute Gallery,
  consumable across subscriptions and regions ([ADR-0007](docs/adr/0007-shared-talos-image-in-management.md)).
- **Zero-trust access** via Twingate connectors — no public management endpoints
  ([ADR-0001](docs/adr/0001-twingate-connectors-per-environment.md)).
- **Three-zone DNS** — security owns the zones and sensitive records; developers
  self-serve internal app hostnames in-cluster via external-dns, no PR
  ([ADR-0008](docs/adr/0008-dns-delegated-self-service.md)).
- **Team ownership as a control**, enforced by [`CODEOWNERS`](.github/CODEOWNERS).

## Architecture

![The four infrastructure layers — Management, Network & Security, Talos Cluster, and
Applications — stacked bottom to top. Management publishes a shared Talos image via the
Compute Gallery; the upper layers resolve the lower ones through Azure data source
lookups rather than remote state.](docs/diagrams/infra-layers.png)

Four conceptual layers, each with a clear owner:

| Layer | Location | Owner | Contents |
|-------|----------|-------|----------|
| **Management** | `management/` | Platform | Remote-state storage, ACR, Operations Key Vault, shared Talos image (Compute Gallery), optional vWAN |
| **Network & Security** | `environments/{env}/network-and-security/` | Security | VNet, NSGs, Key Vault, managed identities, NAT Gateway, Twingate, DNS zones + IAM, optional vWAN connection |
| **Talos Cluster** | `environments/{env}/talos-cluster/` | Platform | VMSS (control plane + worker pools), Load Balancer, Talos machine configs, workload-identity federation |
| **Applications** | `kubernetes/` | Platform / app teams | Cilium CNI + Ingress + Gateway API, cert-manager, external-dns, Azure CSI, monitoring, RBAC, example apps |

**No state coupling.** Layers reference each other via Azure data sources, not
Terraform remote state — enabling independent lifecycle management, no circular
dependencies, and easier disaster recovery.

### Network topology (prod)

The Azure network and control-plane view: the management subscription (remote state,
ACR, Operations Key Vault, shared Talos image, optional vWAN Hub) and the prod VNet
(Twingate connectors, API Load Balancer, control-plane VMSS across three zones, and a
shared workers subnet holding the general and compute pools).

![Production network topology — the management subscription resources feeding the prod
VNet, with the API Load Balancer fronting three per-zone control-plane VMSS and a single
workers subnet containing the general and compute worker pools.](docs/diagrams/prod-network-topology.png)

### DNS model (three zones per environment)

DNS lives in the security-owned network-and-security layer. See
[ADR-0008](docs/adr/0008-dns-delegated-self-service.md) for the full rationale.

| Zone | Type | Purpose | Change path |
|------|------|---------|-------------|
| `example.com` | Public | Internet-facing records | Terraform PR (security) |
| `int.example.com` | Private (VNet-linked) | Internal apex + top-level/infra records | Terraform PR (security) |
| `apps.int.example.com` | Private (VNet-linked) | Developer app subdomains | Ingress/HTTPRoute annotation → external-dns (**no PR**) |

Public apps get Let's Encrypt certificates (DNS-01;
[ADR-0005](docs/adr/0005-cert-manager-workload-identity.md)); internal apps get
certificates from an in-cluster internal CA. external-dns holds a workload identity
scoped to the apps zone **only**.

### Application traffic, DNS & certificates

The in-cluster view of how requests reach applications and how DNS records and TLS
certificates are provisioned — public traffic via the vWAN firewall and internal
traffic via Twingate, both landing on Cilium Gateways, plus cert-manager and
external-dns writing to the DNS zones through workload-identity federation. Mermaid
source: [`docs/diagrams/kubernetes-internals.md`](docs/diagrams/kubernetes-internals.md).

![Kubernetes internals — public and internal traffic flowing through Cilium Gateways to
Services and pods, with cert-manager issuing TLS certificates and external-dns writing
records to the Azure DNS zones via workload-identity federation.](docs/diagrams/kubernetes-internals.png)

## Monitoring

**Monitoring ships with the cluster, not after it.** In practice monitoring is usually
an afterthought — the cluster goes live, runs blind for months, and someone eventually
tries to retrofit an observability stack into a busy production cluster. That
retrofit is where things break: node-exporter needs a privileged namespace, Prometheus
wants large PVCs and a lot of memory on nodes already at their limit, and the initial
scrape of every pod in the estate lands on an unprepared control plane. I've watched
exactly that destabilise production services badly enough that the monitoring effort
was abandoned — leaving the cluster blind *and* the team wary of trying again.

So `kube-prometheus-stack` (Prometheus, Grafana, Alertmanager) is part of the platform
install in step 4, before workloads arrive. Capacity for it is budgeted into the node
pools from day one, and the first time it scrapes a cluster there is nothing on there
to disturb.

![Grafana cluster dashboard showing network I/O pressure over time, plus gauges for
cluster memory usage at 55%, CPU usage at 12.52% of 2 cores, and filesystem usage at
8.35% of 36.45 GiB.](docs/images/grafana-cluster-dashboard.png)

| Component | Dev | Prod |
|-----------|-----|------|
| Prometheus | 1 replica, 20Gi LRS, 7d retention | 2 replicas, 100Gi ZRS, 30d retention |
| Alertmanager | 1 replica, 2Gi LRS | 2 replicas, 5Gi ZRS |
| Grafana | 1 replica, 5Gi LRS | 2 replicas, 10Gi ZRS |

Talos-specific tuning is already applied in
[`kubernetes/infrastructure/monitoring/`](kubernetes/infrastructure/monitoring/):
scrape targets that don't exist on Talos are disabled (`kubeControllerManager`,
`kubeScheduler`, `kubeEtcd`, and `kubeProxy` — replaced by Cilium), node-exporter has
filesystem exclusions for the immutable root, and every component tolerates the
control-plane taint so no node goes unmonitored.

```bash
kubectl create namespace monitoring
kubectl label namespace monitoring pod-security.kubernetes.io/enforce=privileged

helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring --version 66.3.1 \
  -f kubernetes/infrastructure/monitoring/values-common.yaml \
  -f kubernetes/infrastructure/monitoring/values-dev.yaml   # or values-prod.yaml
```

Dev ships with `admin` / `admin` for Grafana; prod expects the admin credential to come
from external secret management. See the
[monitoring README](kubernetes/infrastructure/monitoring/README.md) for access, upgrade,
and tuning details.

## Directory Structure

```
azure-talos-clusters/
├── management/                       # Shared: state, ACR, ops KV, Talos image, vWAN
├── environments/
│   ├── dev/
│   │   ├── network-and-security/     # VNet, NSGs, KV, IAM, Twingate, DNS, vWAN
│   │   └── talos-cluster/            # VMSS + LB + Talos configs
│   └── prod/
│       ├── network-and-security/
│       └── talos-cluster/
├── kubernetes/
│   ├── apps/
│   │   └── echo-test/                # Minimal example workload
│   └── infrastructure/
│       ├── cilium/                   # CNI + Ingress
│       ├── cert-manager/             # TLS: Let's Encrypt (public) + internal CA
│       ├── external-dns/             # Self-service internal DNS (apps zone)
│       ├── gateway-api/              # Internal + public Gateways/HTTPRoutes
│       ├── ingress-examples/         # Example Ingress + wildcard cert
│       ├── azure-csi/                # Storage classes
│       ├── monitoring/               # kube-prometheus-stack
│       └── rbac/                     # Talos node RBAC
├── modules/
│   ├── vnet/  nsg/  nat-gateway/  key-vault/  dns/
│   ├── vmss/  talos-config/  talos-image/  custom-roles/
│   ├── twingate-connector-vm/
│   └── vwan/  vwan-connection/
├── docs/
│   ├── adr/                          # Architecture Decision Records
│   ├── diagrams/                     # Prod network topology + K8s internals diagrams
│   ├── images/                       # Screenshots (Grafana cluster dashboard)
│   ├── ROADMAP.md
│   └── infra-layers.png              # Layer diagram
├── TAGGING_STANDARDS.md
├── CLAUDE.md
└── LICENSE
```

## Environment Comparison

Defaults ship a small dev cluster and an HA prod cluster; every value is a variable.

| Aspect | Dev | Prod |
|--------|-----|------|
| VNet CIDR | `10.100.0.0/16` | `10.200.0.0/16` |
| Control plane | 1 × `D2as_v5` | 3 × `D4as_v5` (HA) |
| Worker pools | 1 general (`D4as_v5`) | general (`D4as_v5`, 2–6) + compute (`D8as_v5`, 3–9) |
| Disk redundancy | LRS | ZRS |
| Key Vault purge protection | Disabled | Enabled |
| API LB IP | `10.100.2.10` | `10.200.2.10` |
| Default storage class | `managed-csi-premium-lrs` | `managed-csi-premium-zrs` |

## Deployment

### Prerequisites

- Azure CLI (authenticated) · Terraform ≥ 1.9 · `talosctl` · `kubectl` · `helm`
- For the image build in the management layer: `curl`, `unxz`

Copy each layer's `terraform.tfvars.example` to `terraform.tfvars` and fill in your
values. Storage-account and ACR names are globally unique — override the defaults.

### 1. Management (one-time)

```bash
cd management
terraform init
terraform apply -var="azure_subscription_id=<mgmt-sub-id>"

# After the first apply, uncomment backend.tf and migrate state:
terraform init -migrate-state
```

This creates state storage, ACR, the Operations Key Vault, and builds the shared
Talos image into a Compute Gallery.

### 2. Network & Security

```bash
cd environments/dev/network-and-security   # or prod
terraform init
terraform apply -var="azure_subscription_id=<sub-id>"
```

Optional features (all default off) — Twingate, DNS zones, cert-manager/external-dns
identities, vWAN — are toggled by variables in `terraform.tfvars`. See the ADRs and
`CLAUDE.md` for each flow.

### 3. Talos Cluster

```bash
cd environments/dev/talos-cluster          # or prod
terraform init
terraform apply -var="azure_subscription_id=<sub-id>"

# Save talosconfig and bootstrap the cluster (ONCE, on the first control-plane node)
terraform output -raw talosconfig > talosconfig
export TALOSCONFIG=$(pwd)/talosconfig
talosctl bootstrap --nodes <control-plane-ip>
talosctl health   --nodes <control-plane-ip>
talosctl kubeconfig --nodes <control-plane-ip>
```

### 4. Kubernetes Platform

Install the in-cluster platform with Helm + `kubectl`. See each component's README
under `kubernetes/infrastructure/` for values and options.

```bash
# Cilium CNI + Ingress
helm install cilium cilium/cilium --version 1.16.3 --namespace kube-system \
  -f kubernetes/infrastructure/cilium/values-common.yaml \
  -f kubernetes/infrastructure/cilium/values-dev.yaml

# cert-manager (+ ClusterIssuers: edit cluster-issuers.yaml first)
helm install cert-manager jetstack/cert-manager --namespace cert-manager \
  --create-namespace --version v1.16.2 --set crds.enabled=true
kubectl apply -f kubernetes/infrastructure/cert-manager/

# Storage classes, monitoring, RBAC, external-dns, Gateway API ...
kubectl apply -f kubernetes/infrastructure/azure-csi/storage-classes.yaml
kubectl apply -f kubernetes/infrastructure/rbac/
```

Then deploy the example app:

```bash
kubectl apply -f kubernetes/apps/echo-test/
```

## Multi-Subscription Support

Environments can live in different subscriptions from the management resources. Set
`management_subscription_id` (and add `subscription_id` to the backend block when
using remote state cross-subscription). The Terraform identity needs, cross
subscription: `Storage Blob Data Contributor` on the state account,
`Key Vault Secrets User` on the ops Key Vault, `Reader` on the Talos image gallery,
and `Network Contributor` on the vWAN Hub RG (if using vWAN). See `CLAUDE.md`.

## Talos-Specific Notes

- **Immutable filesystem** — cannot create dirs under `/var/log/`; disable audit
  logging in the machine config.
- **certSANs** — IP/hostname only, never include ports.
- **No SSH** — API-only management via `talosctl`.
- **KubePrism** — use `localhost:7445` for in-cluster API access.
- **clusterDNS** — set explicitly when using a custom service subnet.
- **trustd** — workers need port `50001` to the control plane for cert signing.

## Production Checklist

- [ ] Decide subscription strategy (single vs multi-subscription) and configure
      cross-subscription RBAC.
- [ ] Set `management_cidrs` for private/Twingate access.
- [ ] Uncomment `backend.tf` after the management apply (add `subscription_id` if
      multi-subscription).
- [ ] Store Twingate secrets in the Operations Key Vault; enable Twingate.
- [ ] Configure public/internal-apex DNS records; update registrar nameservers.
- [ ] Enable `cert_manager` and `external_dns` identities; configure the Talos OIDC
      issuer; enable federation in the cluster layer; annotate the service accounts.
- [ ] Connect to the central vWAN if used; adjust firewall rules for app traffic.
- [ ] Deploy monitoring with prod values (HA, ZRS); set Grafana admin via an external
      secret; configure alerting.
- [ ] Set up autoscaling (via Azure CLI) and backups for etcd and PVCs.

## Documentation

- **[docs/adr/](docs/adr/)** — Architecture Decision Records (the "why").
- **[docs/ROADMAP.md](docs/ROADMAP.md)** — planned direction (list-driven worker pools,
  first-class autoscaling, GitOps, backup/DR, policy, and more).
- **[CLAUDE.md](CLAUDE.md)** — working notes, common commands, and gotchas.
- **[TAGGING_STANDARDS.md](TAGGING_STANDARDS.md)** — resource tagging conventions.

## License

See [LICENSE](LICENSE).
