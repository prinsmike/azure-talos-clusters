variable "name" {
  description = "Name of the Virtual WAN"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "hub_address_prefix" {
  description = "Address prefix for the Virtual Hub (minimum /24)"
  type        = string
  default     = "10.250.0.0/23"

  validation {
    condition     = can(cidrhost(var.hub_address_prefix, 0))
    error_message = "Must be a valid CIDR block."
  }
}

variable "firewall_sku" {
  description = "Azure Firewall SKU tier (Standard or Premium)"
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Premium"], var.firewall_sku)
    error_message = "Must be Standard or Premium."
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "dnat_rules" {
  description = "List of DNAT rules for inbound traffic"
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
