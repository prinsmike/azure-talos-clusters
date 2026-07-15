variable "talos_version" {
  description = "Talos Linux version (with leading 'v'; the gallery image version strips it)"
  type        = string
  default     = "v1.11.5"
}

variable "schematic_id" {
  description = "Talos Image Factory schematic ID (optional, uses default if not set)"
  type        = string
  default     = null
}

variable "storage_account_name" {
  description = "Storage account name for the VHD upload (globally unique)"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name (the management RG that owns the shared image)"
  type        = string
}

variable "location" {
  description = "Azure region for the gallery and the source managed image"
  type        = string
}

# -----------------------------------------------------------------------------
# Compute Gallery
# -----------------------------------------------------------------------------

variable "gallery_name" {
  description = "Azure Compute Gallery name (alphanumeric, periods, underscores; no hyphens)"
  type        = string
  default     = "gal_talos"
}

variable "image_definition_name" {
  description = "Shared image definition name"
  type        = string
  default     = "talos-azure-amd64"
}

variable "image_publisher" {
  description = "Image definition identifier: publisher"
  type        = string
  default     = "talos"
}

variable "image_offer" {
  description = "Image definition identifier: offer"
  type        = string
  default     = "talos-linux"
}

variable "image_sku" {
  description = "Image definition identifier: SKU"
  type        = string
  default     = "talos-amd64"
}

variable "target_regions" {
  description = "Extra regions to replicate the image version to (the gallery's own region is always included). Set these to the regions where clusters run."
  type        = list(string)
  default     = []
}

variable "regional_replica_count" {
  description = "Number of replicas to create in each target region"
  type        = number
  default     = 1
}

variable "reader_principal_ids" {
  description = "Object IDs to grant Reader on the gallery (cross-subscription consumers that must resolve the image version ID)"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default     = {}
}
