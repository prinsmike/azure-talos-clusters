# Shared Talos Image (Change A)
#
# Builds ONE Talos Linux image in the management layer and publishes it to an
# Azure Compute Gallery, so every cluster — including clusters in other
# subscriptions or regions — consumes a single source of truth by data-source
# lookup (see docs/adr/0007-shared-talos-image-in-management.md).
#
# Cluster layers reference module output `image_version_id` via
# `data.azurerm_shared_image_version`. Cross-subscription consumers need Reader
# on the gallery — list their object IDs in `talos_image_reader_principal_ids`.

module "talos_image" {
  source = "../modules/talos-image"
  count  = var.create_talos_image ? 1 : 0

  talos_version        = var.talos_version
  schematic_id         = var.talos_schematic_id
  storage_account_name = var.talos_image_storage_account_name
  resource_group_name  = azurerm_resource_group.tfstate.name
  location             = var.location

  gallery_name          = var.talos_gallery_name
  image_definition_name = var.talos_image_definition_name
  target_regions        = var.talos_image_target_regions
  reader_principal_ids  = var.talos_image_reader_principal_ids

  tags = merge(var.tags, {
    Component = "talos-image"
  })
}
