# Talos Image Module
#
# Downloads the Talos VHD from the Talos Image Factory, uploads it as a page blob,
# builds an Azure Managed Image from it, and publishes that image to an Azure
# Compute Gallery (Shared Image Gallery) as a versioned image.
#
# Publishing to a Compute Gallery — rather than referencing a plain managed image —
# lets clusters in *other* subscriptions/regions consume a single shared Talos image
# by data-source lookup. Grant consumers `Reader` on the gallery via
# `reader_principal_ids` (see docs/adr/0007-shared-talos-image-in-management.md).

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

locals {
  # Default schematic (no customizations)
  schematic_id  = coalesce(var.schematic_id, "376567988ad370138ad8b2698212367b8edcb69b5fd68c80be1f2ec7d603b4ba")
  image_url     = "https://factory.talos.dev/image/${local.schematic_id}/${var.talos_version}/azure-amd64.vhd.xz"
  download_path = "${path.module}/.downloads"
  vhd_filename  = "talos-${var.talos_version}-azure-amd64.vhd"
  vhd_path      = "${local.download_path}/${local.vhd_filename}"

  # Gallery image versions must be numeric MAJOR.MINOR.PATCH — strip the leading "v".
  image_version = trimprefix(var.talos_version, "v")

  # Always replicate to the gallery's own region, plus any extra requested regions
  # (typically the regions where clusters run).
  replica_regions = distinct(concat([var.location], var.target_regions))
}

resource "azurerm_storage_account" "talos_images" {
  name                            = var.storage_account_name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  allow_nested_items_to_be_public = false

  tags = var.tags
}

resource "azurerm_storage_container" "vhds" {
  name                  = "talos-vhds"
  storage_account_id    = azurerm_storage_account.talos_images.id
  container_access_type = "private"
}

resource "null_resource" "download_talos_image" {
  triggers = {
    talos_version = var.talos_version
    image_url     = local.image_url
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      mkdir -p ${local.download_path}
      echo "Downloading Talos ${var.talos_version} Azure VHD..."
      curl -L -o ${local.vhd_path}.xz ${local.image_url}
      echo "Decompressing VHD..."
      unxz -f ${local.vhd_path}.xz
      echo "Talos VHD ready at ${local.vhd_path}"
    EOT
  }
}

resource "null_resource" "upload_vhd" {
  depends_on = [
    null_resource.download_talos_image,
    azurerm_storage_container.vhds
  ]

  triggers = {
    talos_version        = var.talos_version
    storage_account_name = azurerm_storage_account.talos_images.name
    download_id          = null_resource.download_talos_image.id
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "Deleting old VHD blob if exists..."
      az storage blob delete \
        --account-name ${azurerm_storage_account.talos_images.name} \
        --container-name ${azurerm_storage_container.vhds.name} \
        --name ${local.vhd_filename} \
        --account-key "$AZURE_STORAGE_KEY" \
        --auth-mode key 2>/dev/null || true

      echo "Uploading VHD to Azure Storage..."
      az storage blob upload \
        --account-name ${azurerm_storage_account.talos_images.name} \
        --container-name ${azurerm_storage_container.vhds.name} \
        --name ${local.vhd_filename} \
        --file ${local.vhd_path} \
        --account-key "$AZURE_STORAGE_KEY" \
        --type page \
        --overwrite
    EOT

    environment = {
      AZURE_STORAGE_KEY = azurerm_storage_account.talos_images.primary_access_key
    }
  }
}

# Managed image built from the uploaded VHD. This is the *source* for the gallery
# image version below; it is not consumed directly by clusters.
resource "azurerm_image" "talos" {
  depends_on = [null_resource.upload_vhd]

  name                = "talos-${replace(var.talos_version, ".", "-")}-azure-amd64"
  resource_group_name = var.resource_group_name
  location            = var.location
  hyper_v_generation  = "V2"

  os_disk {
    os_type      = "Linux"
    os_state     = "Generalized"
    blob_uri     = "${azurerm_storage_account.talos_images.primary_blob_endpoint}${azurerm_storage_container.vhds.name}/${local.vhd_filename}"
    size_gb      = 10
    storage_type = "Standard_LRS"
  }

  tags = merge(var.tags, {
    talos-version = var.talos_version
    image-source  = "image-factory"
  })
}

# -----------------------------------------------------------------------------
# Azure Compute Gallery (Shared Image Gallery)
# -----------------------------------------------------------------------------

resource "azurerm_shared_image_gallery" "talos" {
  name                = var.gallery_name
  resource_group_name = var.resource_group_name
  location            = var.location
  description         = "Shared Talos Linux images consumed by all clusters (cross-subscription/region)."

  tags = var.tags
}

resource "azurerm_shared_image" "talos" {
  name                = var.image_definition_name
  gallery_name        = azurerm_shared_image_gallery.talos.name
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Linux"
  hyper_v_generation  = "V2"
  architecture        = "x64"
  specialized         = false # Generalized

  identifier {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.image_sku
  }

  tags = var.tags
}

resource "azurerm_shared_image_version" "talos" {
  name                = local.image_version
  gallery_name        = azurerm_shared_image_gallery.talos.name
  image_name          = azurerm_shared_image.talos.name
  resource_group_name = var.resource_group_name
  location            = var.location
  managed_image_id    = azurerm_image.talos.id

  dynamic "target_region" {
    for_each = local.replica_regions
    content {
      name                   = target_region.value
      regional_replica_count = var.regional_replica_count
      storage_account_type   = "Standard_LRS"
    }
  }

  tags = merge(var.tags, {
    talos-version = var.talos_version
  })
}

# -----------------------------------------------------------------------------
# Cross-subscription consumption — grant Reader on the gallery to each consumer
# principal (e.g. the identity that runs `terraform apply` for a cluster in
# another subscription). Reader is required to resolve the image version ID.
# -----------------------------------------------------------------------------

resource "azurerm_role_assignment" "gallery_reader" {
  for_each = toset(var.reader_principal_ids)

  scope                = azurerm_shared_image_gallery.talos.id
  role_definition_name = "Reader"
  principal_id         = each.value
}
