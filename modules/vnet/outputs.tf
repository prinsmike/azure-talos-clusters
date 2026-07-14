output "id" {
  description = "VNet ID"
  value       = azurerm_virtual_network.this.id
}

output "name" {
  description = "VNet name"
  value       = azurerm_virtual_network.this.name
}

output "address_space" {
  description = "VNet address space"
  value       = azurerm_virtual_network.this.address_space
}

output "subnets" {
  description = "Map of subnet name to subnet details"
  value = {
    for k, v in azurerm_subnet.this : k => {
      id   = v.id
      name = v.name
      cidr = v.address_prefixes[0]
    }
  }
}

output "subnet_ids" {
  description = "Map of subnet name to subnet ID"
  value       = { for k, v in azurerm_subnet.this : k => v.id }
}
