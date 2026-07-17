# Architecture Decision Records

This directory contains Architecture Decision Records (ADRs) for the
azure-talos-clusters project.

## What is an ADR?

An ADR is a document that captures an important architectural decision along with
its context and consequences. ADRs help us:

- Remember why decisions were made
- Onboard new contributors quickly
- Revisit decisions when context changes

## ADR Index

| ID | Title | Status | Date |
|----|-------|--------|------|
| [0001](0001-twingate-connectors-per-environment.md) | Deploy Twingate Connectors Per Environment | Accepted | 2025-11-29 |
| [0002](0002-talos-secrets-external-storage.md) | External Storage for Talos Machine Secrets | Accepted (partial) | 2025-11-30 |
| [0003](0003-operations-key-vault-for-secrets.md) | Operations Key Vault for Centralized Secrets | Accepted | 2025-11-30 |
| [0004](0004-dns-management-per-environment.md) | DNS Management Per Environment | Superseded by [0008](0008-dns-delegated-self-service.md) | 2025-11-30 |
| [0005](0005-cert-manager-workload-identity.md) | cert-manager Workload Identity for DNS-01 | Accepted | 2025-12-01 |
| [0006](0006-vwan-hub-spoke-connectivity.md) | vWAN Hub-Spoke Connectivity | Accepted | 2025-12-11 |
| [0007](0007-shared-talos-image-in-management.md) | Shared Talos Image in the Management Layer | Accepted | 2026-07-15 |
| [0008](0008-dns-delegated-self-service.md) | DNS — Security-Owned Zones with Delegated Self-Service | Accepted | 2026-07-15 |

## Creating a New ADR

1. Copy the template below.
2. Name the file `NNNN-short-title.md` (increment the number).
3. Fill in all sections.
4. Add it to the index above.

### Template

```markdown
# ADR-NNNN: Title

## Status

[Proposed | Accepted | Deprecated | Superseded by ADR-XXXX]

## Date

YYYY-MM-DD

## Context

What is the issue that is motivating this decision?

## Decision

What is the change that we're proposing and/or doing?

## Rationale

Why did we choose this option over alternatives?

## Consequences

What becomes easier or more difficult because of this decision?
```
