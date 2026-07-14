output "id" {
  description = "NAT gateway ID"
  value       = azurerm_nat_gateway.this.id
}

output "name" {
  description = "NAT gateway name"
  value       = azurerm_nat_gateway.this.name
}

output "public_ip" {
  description = "NAT gateway public IP address"
  value       = azurerm_public_ip.this.ip_address
}

output "public_ip_id" {
  description = "NAT gateway public IP ID"
  value       = azurerm_public_ip.this.id
}
