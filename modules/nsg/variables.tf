variable "name" {
  description = "NSG name"
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

variable "rules" {
  description = "List of NSG rules"
  type = list(object({
    name                       = string
    priority                   = number
    direction                  = string # "Inbound" or "Outbound"
    access                     = string # "Allow" or "Deny"
    protocol                   = string # "Tcp", "Udp", "Icmp", "*"
    source_port_range          = string
    destination_port_range     = optional(string)
    destination_port_ranges    = optional(list(string))
    source_address_prefix      = optional(string)
    source_address_prefixes    = optional(list(string))
    destination_address_prefix = string
  }))
  default = []

  validation {
    condition = alltrue([
      for rule in var.rules : contains(["Inbound", "Outbound"], rule.direction)
    ])
    error_message = "Direction must be 'Inbound' or 'Outbound'."
  }

  validation {
    condition = alltrue([
      for rule in var.rules : contains(["Allow", "Deny"], rule.access)
    ])
    error_message = "Access must be 'Allow' or 'Deny'."
  }
}

variable "subnet_ids" {
  description = "Map of subnet name to subnet ID for NSG association"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default     = {}
}
