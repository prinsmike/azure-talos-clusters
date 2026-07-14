# DNS Module Outputs

output "zone_id" {
  description = "The ID of the DNS zone"
  value       = var.is_private ? azurerm_private_dns_zone.this[0].id : azurerm_dns_zone.this[0].id
}

output "zone_name" {
  description = "The name of the DNS zone"
  value       = var.name
}

output "name_servers" {
  description = "The name servers for the public DNS zone (empty for private zones)"
  value       = var.is_private ? [] : azurerm_dns_zone.this[0].name_servers
}

output "is_private" {
  description = "Whether this is a private DNS zone"
  value       = var.is_private
}

output "a_records" {
  description = "Map of A record names to their FQDNs"
  value = var.is_private ? {
    for name, record in azurerm_private_dns_a_record.this : name => record.fqdn
    } : {
    for name, record in azurerm_dns_a_record.this : name => record.fqdn
  }
}

output "cname_records" {
  description = "Map of CNAME record names to their FQDNs"
  value = var.is_private ? {
    for name, record in azurerm_private_dns_cname_record.this : name => record.fqdn
    } : {
    for name, record in azurerm_dns_cname_record.this : name => record.fqdn
  }
}
