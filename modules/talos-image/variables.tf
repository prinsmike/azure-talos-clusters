variable "talos_version" {
  description = "Talos Linux version"
  type        = string
  default     = "v1.11.5"
}

variable "schematic_id" {
  description = "Talos Image Factory schematic ID (optional, uses default if not set)"
  type        = string
  default     = null
}

variable "storage_account_name" {
  description = "Storage account name for VHD upload"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default     = {}
}
