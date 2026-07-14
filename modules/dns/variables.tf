# DNS Module Variables
# Supports both private (internal) and public DNS zones

variable "name" {
  description = "Name of the DNS zone (e.g., dev.company.com)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]*[a-z0-9]$", var.name))
    error_message = "DNS zone name must be a valid domain name."
  }
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "is_private" {
  description = "Whether this is a private DNS zone (true) or public (false)"
  type        = bool
  default     = false
}

variable "virtual_network_links" {
  description = "List of virtual networks to link to private DNS zone (only used when is_private = true)"
  type = list(object({
    name                 = string
    virtual_network_id   = string
    registration_enabled = optional(bool, false)
  }))
  default = []
}

variable "a_records" {
  description = "List of A records to create"
  type = list(object({
    name    = string
    ttl     = optional(number, 300)
    records = list(string) # List of IPv4 addresses
  }))
  default = []
}

variable "cname_records" {
  description = "List of CNAME records to create"
  type = list(object({
    name   = string
    ttl    = optional(number, 300)
    record = string # Target domain
  }))
  default = []
}

variable "txt_records" {
  description = "List of TXT records to create"
  type = list(object({
    name    = string
    ttl     = optional(number, 300)
    records = list(string)
  }))
  default = []
}

variable "mx_records" {
  description = "List of MX records to create (public zones only)"
  type = list(object({
    name = string
    ttl  = optional(number, 300)
    records = list(object({
      preference = number
      exchange   = string
    }))
  }))
  default = []
}

variable "srv_records" {
  description = "List of SRV records to create"
  type = list(object({
    name = string
    ttl  = optional(number, 300)
    records = list(object({
      priority = number
      weight   = number
      port     = number
      target   = string
    }))
  }))
  default = []
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
