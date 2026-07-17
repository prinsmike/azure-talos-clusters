# Roadmap

This project ships today as an **Azure + Terraform + Twingate + vWAN + ACR** stack —
a working, opinionated baseline. This roadmap captures the intended direction:
additional platform capabilities built on that stack.

Items here are **directional and not yet implemented** unless linked to shipped code.
Priorities and timelines are indicative, not commitments. Contributions welcome.

## Guiding principles

- **Zero-trust throughout** — authenticated, least-privilege, micro-segmented, assume
  breach.
- **Everything opt-in.** New capabilities land disabled-by-default and driven by
  variables, so existing deployments are never forced to change.
- **Prefer self-hostable, open-source components** for the in-cluster platform layer
  where they meet the bar.

## Cluster shape

- **List-driven worker pools.** Today dev has one pool and prod has general + compute
  pools defined as explicit blocks. Move to a fully list-driven definition so pools
  (general / compute / memory / GPU) are declared as data:

  | Pool | Purpose | Typical sizing |
  |------|---------|----------------|
  | General | Standard workloads | 2–4 vCPU, 8 GB RAM |
  | Compute | CPU-intensive | 8+ vCPU, 16 GB RAM |
  | Memory | In-memory workloads | 4 vCPU, 32 GB+ RAM |
  | GPU | ML/AI workloads | GPU-enabled instances |

- **Autoscaling** as first-class Terraform config (today it is applied via the Azure
  CLI to work around a provider limitation).

## DNS & policy

- **Name-squatting prevention** under `apps.int.example.com`. The three-zone model
  ([ADR-0008](adr/0008-dns-delegated-self-service.md)) lets developers self-serve
  hostnames but does not, by default, stop one team claiming another's name. Add a
  policy engine (**Kyverno** or **Gatekeeper**) restricting each team to
  `*.<team>.apps.int.example.com`.
- **Security zones** as an explicit model: public, management, data, and
  domain-specific zones, with micro-segmentation enforced by Cilium network policy.

## Platform additions (application layer)

Candidate in-cluster platform components, roughly in priority order:

- **GitOps**: FluxCD (or Argo CD) to reconcile the `kubernetes/` tree.
- **Backup/DR**: Velero for cluster and PVC backups; documented etcd backup.
- **Observability**: Loki (logs) and Tempo (traces) alongside the existing
  Prometheus/Grafana/Alertmanager stack; Hubble for network flow visibility.
- **Identity**: Dex as an OIDC provider for cluster and app SSO.
- **CI/CD**: Tekton pipelines; Atlantis for Terraform plan/apply on PRs.
- **Policy**: Open Policy Agent / Kyverno for admission control (ties into DNS policy
  above).

## Security hardening

- Customer-managed-key encryption for Terraform state.
- External generation of Talos machine secrets (Option A in
  [ADR-0002](adr/0002-talos-secrets-external-storage.md)) once provider support allows.
- WireGuard node encryption enabled by default in production (Cilium).
- Regular automated Talos and Kubernetes version upgrades.
