output "vwan_id" {
  description = "Virtual WAN ID"
  value       = azurerm_virtual_wan.this.id
}

output "vwan_name" {
  description = "Virtual WAN name"
  value       = azurerm_virtual_wan.this.name
}

output "hub_id" {
  description = "Virtual Hub ID"
  value       = azurerm_virtual_hub.this.id
}

output "hub_name" {
  description = "Virtual Hub name"
  value       = azurerm_virtual_hub.this.name
}

output "hub_default_route_table_id" {
  description = "Virtual Hub default route table ID"
  value       = azurerm_virtual_hub.this.default_route_table_id
}

output "firewall_id" {
  description = "Azure Firewall ID"
  value       = azurerm_firewall.this.id
}

output "firewall_name" {
  description = "Azure Firewall name"
  value       = azurerm_firewall.this.name
}

output "firewall_private_ip" {
  description = "Azure Firewall private IP address"
  value       = azurerm_firewall.this.virtual_hub[0].private_ip_address
}

output "firewall_public_ip" {
  description = "Azure Firewall public IP address"
  value       = azurerm_firewall.this.virtual_hub[0].public_ip_addresses[0]
}

output "firewall_policy_id" {
  description = "Firewall Policy ID"
  value       = azurerm_firewall_policy.this.id
}
