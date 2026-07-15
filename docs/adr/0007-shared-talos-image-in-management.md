# ADR-0007: Shared Talos Image in the Management Layer via Azure Compute Gallery

## Status

Accepted

## Date

2026-07-15

## Context

Every Talos cluster boots from a Talos Linux OS image built from the Talos Image
Factory VHD. Originally each cluster layer built its own image:
`modules/talos-image` downloaded the Factory VHD, uploaded it as a page blob to a
per-environment storage account, and created an `azurerm_image` **managed image**
in the cluster's resource group. Every VMSS then referenced that managed image via
`source_image_id`.

This had two problems:

1. **Duplication.** The same image was built once per environment (dev, prod, …),
   each a separate download/upload/managed-image with no shared source of truth.
2. **No cross-subscription/region sharing.** A plain managed image is scoped to a
   single subscription and region. Our target model allows a cluster to live in a
   *different* subscription from management, and a managed image cannot be
   referenced across subscriptions. It also cannot be consumed in another region
   without rebuilding.

We want **one** Talos image, built once, consumable by every cluster regardless of
subscription or region — without introducing `terraform_remote_state` coupling
(the repo deliberately couples layers by Azure name lookups only).

## Decision

Build the Talos image **once in the management layer** and publish it to an
**Azure Compute Gallery** (Shared Image Gallery). Clusters consume the gallery
**image version** by data-source lookup.

**`modules/talos-image` (refactored):**
- Keeps the download / `unxz` / upload-page-blob logic and the `azurerm_image`
  managed image — but that managed image is now only the *source* for the gallery
  version, created in the management RG.
- Adds `azurerm_shared_image_gallery`, `azurerm_shared_image` (definition:
  `os_type = Linux`, `hyper_v_generation = V2`, `architecture = x64`,
  `specialized = false`), and `azurerm_shared_image_version` (name derived from
  `talos_version`, `managed_image_id` = the managed image, replicated to the
  management region plus any `target_regions`).
- Adds `azurerm_role_assignment` granting **Reader** on the gallery to each
  `reader_principal_ids` entry, so cross-subscription consumers can resolve the
  image version ID.
- Outputs `image_version_id` (what VMSS consumes), `gallery_id`,
  `image_definition_id`, and `talos_version`.

**Management layer (`management/talos-image.tf`):** instantiates the module once,
in the management RG, and exports `talos_image_version_id`, `talos_gallery_id`,
`talos_gallery_name`, `talos_image_definition_name`, and `talos_version`.

**Cluster layers:** delete the `module.talos_image` block and instead look up the
shared image version:

```hcl
data "azurerm_shared_image_version" "talos" {
  provider            = azurerm.management
  name                = var.talos_image_version # or "latest"
  image_name          = var.talos_image_definition_name
  gallery_name        = var.talos_gallery_name
  resource_group_name = var.management_resource_group_name
}
```

Every VMSS `source_image_id` becomes `data.azurerm_shared_image_version.talos.id`.

## Rationale

### Managed image vs Compute Gallery

| Aspect | Managed image | Compute Gallery image version |
|--------|---------------|-------------------------------|
| Cross-subscription sharing | No | Yes (with Reader RBAC) |
| Cross-region use | Rebuild per region | Replicate to `target_regions` |
| Versioning | Single, mutable name | Immutable `MAJOR.MINOR.PATCH` versions |
| Single source of truth | Per environment | One, shared by all clusters |
| Disaster recovery | Manual copy | Built-in replication |

### Why keep the managed image at all

`azurerm_shared_image_version` needs a source. `managed_image_id` pointing at the
`azurerm_image` built from the uploaded VHD is the simplest source that preserves
the existing Image Factory workflow. The managed image is an implementation detail;
clusters never reference it directly.

### Why not `terraform_remote_state`

The repo couples layers by Azure name lookups, never remote state. The cluster's
`data.azurerm_shared_image_version` (gallery name + definition + RG, in the
management subscription via a provider alias) preserves that pattern and keeps
layers independently applyable.

## Consequences

- The image is built once; per-environment `sttalosimg{env}` storage accounts and
  per-cluster managed images are gone.
- Clusters in another subscription require **Reader** on the gallery. This must be
  granted (via `talos_image_reader_principal_ids`) before a cross-subscription
  cluster apply can resolve the image — document this in the prod checklist.
- Image versions are immutable; upgrading Talos means publishing a new version and
  pointing clusters at it (or `"latest"`).
- The management apply host still needs `curl`, `unxz`, and the `az` CLI to build
  the VHD. `create_talos_image = false` skips the whole flow.

## Related

- Supersedes the per-cluster image approach in `modules/talos-image` and
  `environments/{env}/talos-cluster/talos-config.tf`.
- Consumed by the cluster layer's VMSS (`modules/vmss` `source_image_id`).
