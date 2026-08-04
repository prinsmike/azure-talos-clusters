# vWAN VNet Connection Module
#
# Creates a Virtual Hub Connection to connect a VNet to an Azure vWAN Hub.
# Supports routing configuration with associated/propagated route tables and static routes.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
  }
}

resource "azurerm_virtual_hub_connection" "this" {
  name                      = var.name
  virtual_hub_id            = var.vwan_hub_id
  remote_virtual_network_id = var.vnet_id
  internet_security_enabled = var.internet_security_enabled

  dynamic "routing" {
    for_each = var.routing_configuration.associated_route_table_id != null || length(var.routing_configuration.propagated_route_tables) > 0 || length(var.routing_configuration.static_routes) > 0 ? [1] : []
    content {
      associated_route_table_id = var.routing_configuration.associated_route_table_id

      dynamic "propagated_route_table" {
        for_each = length(var.routing_configuration.propagated_route_tables) > 0 ? [1] : []
        content {
          route_table_ids = var.routing_configuration.propagated_route_tables
        }
      }

      dynamic "static_vnet_route" {
        for_each = var.routing_configuration.static_routes
        content {
          name                = static_vnet_route.value.name
          address_prefixes    = static_vnet_route.value.address_prefixes
          next_hop_ip_address = static_vnet_route.value.next_hop_ip_address
        }
      }
    }
  }
}
