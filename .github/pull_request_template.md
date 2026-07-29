<!--
Thanks for contributing! Keep this description short and specific.
The `validate` workflow (Repo hygiene · Terraform fmt & validate · YAML parse)
must be green before this can merge into main.
-->

## Summary

<!-- What does this change and why? One or two sentences. -->

## Layer(s) touched

<!-- Tick all that apply. -->

- [ ] Management (`management/`)
- [ ] Network & Security (`environments/{env}/network-and-security/`)
- [ ] Talos Cluster (`environments/{env}/talos-cluster/`)
- [ ] Applications (`kubernetes/`)
- [ ] Modules (`modules/`)
- [ ] Docs / CI only

## Checklist

- [ ] `terraform fmt -recursive` is clean and `terraform validate` passes for each affected layer.
- [ ] YAML manifests parse (kubectl/helm as applicable).
- [ ] No secrets, real subscription/tenant IDs, public IPs, or client-specific names — placeholders only (`example.com`, `00000000-0000-0000-0000-000000000000`).
- [ ] Only `*.tfvars.example` added/changed — never a real `*.tfvars`, state, `talosconfig`, or `kubeconfig`.
- [ ] Ran `./scripts/ci-hygiene.sh` locally (and `./scripts/scrub-local.sh` if available) — passes.
- [ ] Docs updated (README / ADR) if behaviour or interfaces changed.
- [ ] For a new architectural decision: added an ADR under `docs/adr/`.

## Notes for reviewers

<!-- Migrations, manual apply steps, follow-ups, or anything needing extra eyes. -->
