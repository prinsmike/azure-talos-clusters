# -----------------------------------------------------------------------------
# Required Variables
# -----------------------------------------------------------------------------

variable "azure_subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

# -----------------------------------------------------------------------------
# Location
# -----------------------------------------------------------------------------

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

# -----------------------------------------------------------------------------
# Remote State Storage
# -----------------------------------------------------------------------------

variable "resource_group_name" {
  description = "Resource group name for Terraform state storage"
  type        = string
  default     = "rg-talos-ops"
}

variable "storage_account_name" {
  description = "Storage account name (3-24 lowercase alphanumeric, globally unique — you MUST override this)"
  type        = string
  default     = "sttalosstate"

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "Storage account name must be 3-24 lowercase alphanumeric characters."
  }
}

variable "container_name" {
  description = "Blob container name for state files"
  type        = string
  default     = "tfstate"
}

variable "state_storage_replication_type" {
  description = "Storage replication type"
  type        = string
  default     = "GRS"

  validation {
    condition     = contains(["LRS", "GRS", "RAGRS", "ZRS", "GZRS", "RAGZRS"], var.state_storage_replication_type)
    error_message = "Must be one of: LRS, GRS, RAGRS, ZRS, GZRS, RAGZRS."
  }
}

variable "blob_soft_delete_retention_days" {
  description = "Days to retain soft-deleted blobs"
  type        = number
  default     = 30

  validation {
    condition     = var.blob_soft_delete_retention_days >= 1 && var.blob_soft_delete_retention_days <= 365
    error_message = "Must be between 1 and 365 days."
  }
}

variable "container_soft_delete_retention_days" {
  description = "Days to retain soft-deleted containers"
  type        = number
  default     = 30

  validation {
    condition     = var.container_soft_delete_retention_days >= 1 && var.container_soft_delete_retention_days <= 365
    error_message = "Must be between 1 and 365 days."
  }
}

variable "restrict_network_access" {
  description = "Restrict storage account and Key Vault to specific IPs (recommended for production)"
  type        = bool
  default     = true
}

variable "allowed_ip_ranges" {
  description = "IP ranges allowed to access storage and Key Vault (CIDR notation). Required when restrict_network_access=true. Include: office IPs, CI/CD runner IPs, developer IPs."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for cidr in var.allowed_ip_ranges : can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}(/[0-9]{1,2})?$", cidr))
    ])
    error_message = "All entries must be valid CIDR notation."
  }
}

variable "enable_resource_lock" {
  description = "Enable deletion lock on resource group"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Container Registry
# -----------------------------------------------------------------------------

variable "create_container_registry" {
  description = "Create Azure Container Registry"
  type        = bool
  default     = true
}

variable "container_registry_name" {
  description = "Container registry name (5-50 alphanumeric, globally unique — you MUST override this)"
  type        = string
  default     = "acrtalos"

  validation {
    condition     = can(regex("^[a-zA-Z0-9]{5,50}$", var.container_registry_name))
    error_message = "Registry name must be 5-50 alphanumeric characters."
  }
}

variable "container_registry_sku" {
  description = "Container registry SKU"
  type        = string
  default     = "Basic"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.container_registry_sku)
    error_message = "Must be Basic, Standard, or Premium."
  }
}

variable "container_registry_admin_enabled" {
  description = "Enable admin user for registry (DEPRECATED: use managed identity instead for better security)"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Operations Key Vault
# -----------------------------------------------------------------------------

variable "create_operations_key_vault" {
  description = "Create Key Vault for operational secrets (Twingate API token, etc.)"
  type        = bool
  default     = true
}

variable "operations_key_vault_name" {
  description = "Operations Key Vault name (3-24 alphanumeric and hyphens, globally unique)"
  type        = string
  default     = "kv-talos-ops"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{1,22}[a-zA-Z0-9]$", var.operations_key_vault_name))
    error_message = "Key Vault name must be 3-24 characters, start with letter, contain only alphanumeric and hyphens."
  }
}

variable "operations_key_vault_purge_protection" {
  description = "Enable purge protection (prevents permanent deletion)"
  type        = bool
  default     = false
}

variable "operations_key_vault_soft_delete_days" {
  description = "Days to retain soft-deleted secrets"
  type        = number
  default     = 7

  validation {
    condition     = var.operations_key_vault_soft_delete_days >= 7 && var.operations_key_vault_soft_delete_days <= 90
    error_message = "Must be between 7 and 90 days."
  }
}

# -----------------------------------------------------------------------------
# vWAN (Optional - for testing)
# -----------------------------------------------------------------------------

variable "enable_vwan" {
  description = "Deploy vWAN and Azure Firewall for testing vWAN connectivity"
  type        = bool
  default     = false
}

variable "vwan_hub_address_prefix" {
  description = "vWAN Hub address prefix (minimum /24)"
  type        = string
  default     = "10.250.0.0/23"
}

variable "vwan_firewall_sku" {
  description = "Azure Firewall SKU tier (Standard or Premium)"
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Premium"], var.vwan_firewall_sku)
    error_message = "Must be Standard or Premium."
  }
}

variable "vwan_dnat_rules" {
  description = "DNAT rules for inbound traffic through vWAN firewall"
  type = list(object({
    name               = string
    protocols          = list(string)
    source_addresses   = list(string)
    destination_ports  = list(string)
    translated_address = string
    translated_port    = string
  }))
  default = []
}

# -----------------------------------------------------------------------------
# Shared Talos Image (Azure Compute Gallery)
# -----------------------------------------------------------------------------

variable "create_talos_image" {
  description = "Build and publish the shared Talos image to a Compute Gallery. Requires curl, unxz, and the az CLI on the machine running terraform apply."
  type        = bool
  default     = true
}

variable "talos_version" {
  description = "Talos Linux version to publish (with leading 'v')"
  type        = string
  default     = "v1.11.5"
}

variable "talos_schematic_id" {
  description = "Talos Image Factory schematic ID (optional; uses the module default if null)"
  type        = string
  default     = null
}

variable "talos_image_storage_account_name" {
  description = "Storage account for the Talos VHD upload (globally unique)"
  type        = string
  default     = "sttalosimages"

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.talos_image_storage_account_name))
    error_message = "Storage account name must be 3-24 lowercase alphanumeric characters."
  }
}

variable "talos_gallery_name" {
  description = "Azure Compute Gallery name (alphanumeric, periods, underscores; no hyphens)"
  type        = string
  default     = "gal_talos"
}

variable "talos_image_definition_name" {
  description = "Shared image definition name in the gallery"
  type        = string
  default     = "talos-azure-amd64"
}

variable "talos_image_target_regions" {
  description = "Extra regions to replicate the Talos image to (the management region is always included). Set to the regions where clusters run."
  type        = list(string)
  default     = []
}

variable "talos_image_reader_principal_ids" {
  description = "Object IDs granted Reader on the gallery (cross-subscription cluster deployers that must resolve the image version)"
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# Tags
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
