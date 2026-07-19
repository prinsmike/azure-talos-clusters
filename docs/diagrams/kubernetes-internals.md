# Kubernetes Internals — App Traffic, DNS & Certificates (prod)

In-cluster view of how requests reach applications and how DNS records and TLS
certificates are provisioned. Complements `prod-network-topology.png` (the Azure
network / control-plane view). See [ADR-0005](../adr/0005-cert-manager-workload-identity.md)
and [ADR-0008](../adr/0008-dns-delegated-self-service.md) for the rationale.

```mermaid
flowchart TB
  %% ===================== Clients =====================
  publicUser["Public users<br/>(Internet)"]
  adminUser["Internal / admin users"]

  %% ===================== Network edge =====================
  subgraph edge["Network edge (Azure)"]
    fw["vWAN Firewall<br/>public IP + DNAT"]
    tg["Twingate connectors (zero-trust)<br/>or vWAN VPN"]
  end

  publicUser -->|"HTTPS *.example.com"| fw
  adminUser  -->|"HTTPS *.apps.int.example.com"| tg

  %% ===================== Cluster =====================
  subgraph cluster["Talos Kubernetes cluster — worker nodes"]
    direction TB

    subgraph gw["Cilium Gateway API (kube-system)"]
      gwPublic["cilium-gateway-public<br/>Azure internal LB · snet-services<br/>listeners :443 / :80 · *.example.com<br/>TLS: letsencrypt-prod"]
      gwInternal["cilium-gateway-internal<br/>Azure internal LB · snet-services<br/>listeners :443 / :80 · *.apps.int.example.com<br/>TLS: internal-ca"]
    end

    routes["HTTPRoutes"]
    svc["Services (ClusterIP)"]
    pods["Application pods"]

    subgraph platform["Platform controllers"]
      certmgr["cert-manager<br/>ClusterIssuers:<br/>letsencrypt-prod (DNS-01) · internal-ca"]
      extdns["external-dns<br/>writes app DNS records"]
    end

    cni["Cilium CNI<br/>kube-proxy replacement · KubePrism :7445<br/>WireGuard encryption · VXLAN"]
    csi["Azure Disk CSI<br/>managed-csi-premium-zrs"]
  end

  fw -->|"DNAT → internal LB IP (10.200.2.x)"| gwPublic
  tg --> gwInternal
  gwPublic --> routes
  gwInternal --> routes
  routes --> svc --> pods
  cni -.->|"CNI · encrypted pod-to-pod"| pods
  pods -.->|"PVCs → managed disks"| csi

  %% ===================== Azure DNS + identity =====================
  subgraph dns["Azure DNS zones — network-and-security layer"]
    zPublic["example.com<br/>(public)"]
    zIntApex["int.example.com<br/>(private, VNet-linked)"]
    zApps["apps.int.example.com<br/>(private, VNet-linked)"]
  end

  tf["Terraform PR<br/>(security-owned)"]
  wif["Workload Identity Federation<br/>Talos OIDC issuer → Azure managed identities"]

  certmgr -->|"DNS-01 challenge (TXT)"| zPublic
  extdns  -->|"A / CNAME — self-service, no PR"| zApps
  tf -->|"records"| zPublic
  tf -->|"records"| zIntApex

  certmgr -. "assumes identity" .-> wif
  extdns  -. "assumes identity" .-> wif
  certmgr -.->|"issues TLS Secrets"| gwPublic
  certmgr -.->|"issues TLS Secrets"| gwInternal
```

## Traffic flows

- **Public app** — `Internet → vWAN Firewall (DNAT) → cilium-gateway-public
  (internal LB, snet-services) → HTTPRoute → Service → pods`. Hostnames under
  `*.example.com`; TLS from Let's Encrypt (`letsencrypt-prod`, DNS-01).
- **Internal app** — `admin/internal user → Twingate (or vWAN VPN) →
  cilium-gateway-internal (internal LB) → HTTPRoute → Service → pods`. Hostnames
  under `*.apps.int.example.com`; TLS from the in-cluster `internal-ca`.

## DNS ownership (three zones)

| Zone | Type | Who writes records | How |
|------|------|--------------------|-----|
| `example.com` | Public | Security | Terraform PR (+ cert-manager writes DNS-01 TXT) |
| `int.example.com` | Private (VNet-linked) | Security | Terraform PR |
| `apps.int.example.com` | Private (VNet-linked) | Developers | external-dns (Gateway/HTTPRoute annotation, **no PR**) |

external-dns holds a workload identity scoped to the **apps zone only**; cert-manager
holds a separate identity able to solve DNS-01 in the **public zone**. Both use
Talos OIDC → Azure federated identity credentials (no stored secrets).
