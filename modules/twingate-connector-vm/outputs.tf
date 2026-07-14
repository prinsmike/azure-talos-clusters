# -----------------------------------------------------------------------------
# Twingate Outputs
# -----------------------------------------------------------------------------

output "remote_network_id" {
  description = "Twingate remote network ID"
  value       = twingate_remote_network.this.id
}

output "remote_network_name" {
  description = "Twingate remote network name"
  value       = twingate_remote_network.this.name
}

output "connector_ids" {
  description = "Twingate connector IDs"
  value       = twingate_connector.this[*].id
}

output "connector_names" {
  description = "Twingate connector names"
  value       = twingate_connector.this[*].name
}

# -----------------------------------------------------------------------------
# Azure Outputs
# -----------------------------------------------------------------------------

output "vm_ids" {
  description = "Azure VM IDs"
  value       = azurerm_linux_virtual_machine.connector[*].id
}

output "vm_names" {
  description = "Azure VM names"
  value       = azurerm_linux_virtual_machine.connector[*].name
}

output "vm_private_ips" {
  description = "Azure VM private IP addresses"
  value       = azurerm_network_interface.connector[*].private_ip_address
}

output "network_interface_ids" {
  description = "Azure Network Interface IDs"
  value       = azurerm_network_interface.connector[*].id
}

# -----------------------------------------------------------------------------
# Resource Outputs
# -----------------------------------------------------------------------------

output "resource_ids" {
  description = "Twingate resource IDs"
  value       = { for k, v in twingate_resource.this : k => v.id }
}

output "resource_addresses" {
  description = "Twingate resource addresses"
  value       = { for k, v in twingate_resource.this : k => v.address }
}
