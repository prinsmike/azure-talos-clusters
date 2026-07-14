variable "name" {
  description = "Key Vault name (globally unique, 3-24 chars)"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{1,22}[a-zA-Z0-9]$", var.name))
    error_message = "Key Vault name must be 3-24 characters, start with a letter, and contain only alphanumerics and hyphens."
  }
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "sku_name" {
  description = "Key Vault SKU"
  type        = string
  default     = "standard"

  validation {
    condition     = contains(["standard", "premium"], var.sku_name)
    error_message = "SKU must be 'standard' or 'premium'."
  }
}

variable "soft_delete_retention_days" {
  description = "Soft delete retention days"
  type        = number
  default     = 7
}

variable "purge_protection_enabled" {
  description = "Enable purge protection"
  type        = bool
  default     = false
}

variable "network_acls_default_action" {
  description = "Default action for network ACLs"
  type        = string
  default     = "Allow"

  validation {
    condition     = contains(["Allow", "Deny"], var.network_acls_default_action)
    error_message = "Must be 'Allow' or 'Deny'."
  }
}

variable "allowed_ip_ranges" {
  description = "IP ranges allowed to access Key Vault (public IPs only)"
  type        = list(string)
  default     = []
}

variable "access_policies" {
  description = "Additional access policies for managed identities"
  type = list(object({
    name                    = string
    object_id               = string
    secret_permissions      = optional(list(string), ["Get", "List"])
    key_permissions         = optional(list(string), [])
    certificate_permissions = optional(list(string), [])
  }))
  default = []
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default     = {}
}
