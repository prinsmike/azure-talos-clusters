variable "name" {
  description = "Name of the Virtual Hub Connection"
  type        = string
}

variable "vwan_hub_id" {
  description = "Resource ID of the vWAN Hub"
  type        = string
}

variable "vnet_id" {
  description = "Resource ID of the VNet to connect"
  type        = string
}

variable "internet_security_enabled" {
  description = "Enable internet security (route internet traffic through vWAN firewall)"
  type        = bool
  default     = true
}

variable "routing_configuration" {
  description = "Routing configuration for the connection"
  type = object({
    associated_route_table_id = optional(string)
    propagated_route_tables   = optional(list(string), [])
    static_routes = optional(list(object({
      name                = string
      address_prefixes    = list(string)
      next_hop_ip_address = optional(string)
    })), [])
  })
  default = {}
}
