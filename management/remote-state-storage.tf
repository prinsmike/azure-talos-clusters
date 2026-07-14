# Remote State Storage Infrastructure
#
# Creates Azure Storage Account and Container for Terraform remote state.
# Features: blob versioning, soft delete, encryption, optional network restrictions.

resource "azurerm_resource_group" "tfstate" {
  name     = var.resource_group_name
  location = var.location

  tags = merge(var.tags, {
    Purpose   = "terraform-state-storage"
    ManagedBy = "terraform-management"
  })
}

resource "azurerm_storage_account" "tfstate" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.tfstate.name
  location                 = azurerm_resource_group.tfstate.location
  account_tier             = "Standard"
  account_replication_type = var.state_storage_replication_type
  account_kind             = "StorageV2"

  # Security
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = true

  # Blob versioning for state history
  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = var.blob_soft_delete_retention_days
    }

    container_delete_retention_policy {
      days = var.container_soft_delete_retention_days
    }
  }

  # Network ACLs
  network_rules {
    default_action = var.restrict_network_access ? "Deny" : "Allow"
    bypass         = ["AzureServices"]
    ip_rules       = var.allowed_ip_ranges
  }

  tags = merge(var.tags, {
    Purpose   = "terraform-state-storage"
    ManagedBy = "terraform-management"
  })
}

resource "azurerm_storage_container" "tfstate" {
  name                  = var.container_name
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private"
}

# Optional: Prevent accidental deletion
resource "azurerm_management_lock" "tfstate" {
  count = var.enable_resource_lock ? 1 : 0

  name       = "prevent-deletion"
  scope      = azurerm_resource_group.tfstate.id
  lock_level = "CanNotDelete"
  notes      = "Prevent accidental deletion of Terraform state storage"
}
