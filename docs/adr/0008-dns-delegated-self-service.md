# ADR-0008: DNS — Security-Owned Zones with Delegated Developer Self-Service

## Status

Accepted (supersedes [ADR-0004](0004-dns-management-per-environment.md))

## Date

2026-07-15

## Context

ADR-0004 gave each environment a single DNS posture: dev had one private zone, prod
had public zones, and they never coexisted. Engineers added every record — internal
or public — by editing Terraform lists and opening a PR. Two forces make that model
insufficient:

1. **Security must own DNS.** Public records and internal top-level/infra records
   (`api`, `vault`, `grafana`, `ingress`, …) are security-sensitive. Every change to
   them should require security sign-off.
2. **Developers need low-friction internal DNS.** Requiring a Terraform PR (against a
   security-owned layer) just to expose an app on the internal network is too slow and
   puts routine app hostnames in front of security reviewers unnecessarily.

We want both: security owns the zones and the sensitive records, **and** developers
self-serve ordinary internal app hostnames without a PR — without weakening the
security boundary to a matter of process/politeness.

## Decision

Adopt a **three-zone model per environment**, all instantiated together in the
security-owned `network-and-security` layer (gated by `CODEOWNERS`):

| Zone | Type | Purpose | Owner | Change path |
|---|---|---|---|---|
| `example.com` | Azure **Public** DNS | Internet-facing records | Security | Terraform PR |
| `int.example.com` | Azure **Private** DNS (VNet-linked) | Internal apex + top-level/infra records | Security | Terraform PR |
| `apps.int.example.com` | Azure **Private** DNS (VNet-linked) | Developer app subdomains | Developers | Ingress/HTTPRoute annotation → external-dns (no PR) |

**Private-zone delegation detail:** Azure Private DNS does *not* use NS-record
delegation between private zones. `apps.int.example.com` is created as a **separate**
private zone; both zones are VNet-linked and Azure's resolver matches the **longest
DNS suffix**, so `myapp.apps.int.example.com` resolves against the apps zone while
`api.int.example.com` resolves against the apex zone. This split is exactly what lets
us scope the self-service identity to the app zone alone.

**Self-service mechanism:** deploy **external-dns** in-cluster (provider
`azure-private-dns`), driven by Service/Ingress/HTTPRoute hostnames. It authenticates
via a **zone-scoped workload identity** (mirroring the cert-manager federation
pattern):

- `network-and-security` (security-owned): create UAMI `id-external-dns-{env}` and
  grant it **`DNS Zone Contributor` on `apps.int.example.com` ONLY** — never the apex
  or public zones. Output `external_dns_identity_client_id`.
- `talos-cluster`: `azurerm_federated_identity_credential` binding
  `system:serviceaccount:external-dns:external-dns` to that UAMI (same OIDC issuer as
  cert-manager).
- `kubernetes/infrastructure/external-dns/`: Helm values with
  `--domain-filter=apps.int.example.com`, `--policy=upsert-only`, a TXT ownership
  registry, and the SA annotated with the identity's client-id.

**TLS:** internal apps (`*.apps.int.example.com`) get certificates from an in-cluster
**internal-CA ClusterIssuer** (`kubernetes/infrastructure/cert-manager/internal-ca-cluster-issuer.yaml`),
because a private zone cannot satisfy Let's Encrypt DNS-01. Public apps keep the
existing cert-manager Let's Encrypt DNS-01 flow on the public zone.

## Consequences

**Positive**

- **Defense in depth**, not just process:
  1. Azure RBAC — external-dns can only write the apps zone.
  2. `--domain-filter` — external-dns is blind to the other zones.
  3. Kubernetes RBAC — only app namespaces create Ingress/HTTPRoute objects.
  4. TXT ownership registry — external-dns only touches its own records.
  5. `CODEOWNERS` — zones, public records, and internal top-level records change only
     via PR to the security-owned layer.
- Developers expose apps with a single hostname annotation; no Terraform, no PR.
- Security retains full control of everything that matters.

**Negative / trade-offs**

- Two private zones per environment instead of one (minor extra Terraform).
- Internal apps trust an internal CA — its root must be distributed to clients /
  via the private-access solution.
- Inter-team name squatting under `apps.int.example.com` is not prevented by default;
  a policy engine (Kyverno/Gatekeeper) restricting each team to
  `*.<team>.apps.int.example.com` is recommended and tracked in `docs/ROADMAP.md`.

## References

- Supersedes ADR-0004 (DNS Management Per Environment).
- Mirrors the workload-identity federation pattern in ADR-0005 (cert-manager).
- Implementation: `environments/*/network-and-security/{dns,iam,outputs,variables}.tf`,
  `kubernetes/infrastructure/external-dns/`,
  `kubernetes/infrastructure/cert-manager/internal-ca-cluster-issuer.yaml`.
