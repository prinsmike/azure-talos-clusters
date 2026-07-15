# -----------------------------------------------------------------------------
# Resource Group
# -----------------------------------------------------------------------------

output "resource_group_name" {
  description = "Network-and-security resource group name"
  value       = azurerm_resource_group.network.name
}

output "resource_group_id" {
  description = "Network-and-security resource group ID"
  value       = azurerm_resource_group.network.id
}

# -----------------------------------------------------------------------------
# Network
# -----------------------------------------------------------------------------

output "vnet_id" {
  description = "VNet ID"
  value       = module.vnet.id
}

output "vnet_name" {
  description = "VNet name"
  value       = module.vnet.name
}

output "subnet_ids" {
  description = "Subnet IDs"
  value       = module.vnet.subnet_ids
}

output "subnet_control_plane_id" {
  description = "Control plane subnet ID"
  value       = module.vnet.subnet_ids["snet-control-plane-${var.environment}"]
}

output "subnet_workers_id" {
  description = "Workers subnet ID"
  value       = module.vnet.subnet_ids["snet-workers-${var.environment}"]
}

output "subnet_services_id" {
  description = "Services subnet ID"
  value       = module.vnet.subnet_ids["snet-services-${var.environment}"]
}

# -----------------------------------------------------------------------------
# NSGs
# -----------------------------------------------------------------------------

output "nsg_control_plane_id" {
  description = "Control plane NSG ID"
  value       = module.nsg_control_plane.id
}

output "nsg_workers_id" {
  description = "Workers NSG ID"
  value       = module.nsg_workers.id
}

output "nsg_services_id" {
  description = "Services NSG ID"
  value       = module.nsg_services.id
}

# -----------------------------------------------------------------------------
# Managed Identities
# -----------------------------------------------------------------------------

output "control_plane_identity_id" {
  description = "Control plane managed identity ID"
  value       = azurerm_user_assigned_identity.control_plane.id
}

output "control_plane_identity_client_id" {
  description = "Control plane managed identity client ID"
  value       = azurerm_user_assigned_identity.control_plane.client_id
}

output "workers_identity_id" {
  description = "Workers managed identity ID"
  value       = azurerm_user_assigned_identity.workers.id
}

output "workers_identity_client_id" {
  description = "Workers managed identity client ID"
  value       = azurerm_user_assigned_identity.workers.client_id
}

# -----------------------------------------------------------------------------
# Key Vault
# -----------------------------------------------------------------------------

output "key_vault_id" {
  description = "Key Vault ID"
  value       = module.key_vault.id
}

output "key_vault_name" {
  description = "Key Vault name"
  value       = module.key_vault.name
}

output "key_vault_uri" {
  description = "Key Vault URI"
  value       = module.key_vault.uri
}

# -----------------------------------------------------------------------------
# NAT Gateway
# -----------------------------------------------------------------------------

output "nat_gateway_id" {
  description = "NAT gateway ID"
  value       = module.nat_gateway.id
}

output "nat_gateway_public_ip" {
  description = "NAT gateway public IP"
  value       = module.nat_gateway.public_ip
}

# -----------------------------------------------------------------------------
# Network Config (for talos-cluster layer)
# -----------------------------------------------------------------------------

output "network_config" {
  description = "Network configuration for talos-cluster layer"
  value = {
    control_plane_subnet_cidr = var.subnet_control_plane_cidr
    workers_subnet_cidr       = var.subnet_workers_cidr
    services_subnet_cidr      = var.subnet_services_cidr
    pods_subnet_cidr          = var.subnet_pods_cidr
    k8s_services_subnet_cidr  = var.subnet_k8s_services_cidr
  }
}

# -----------------------------------------------------------------------------
# Twingate
# -----------------------------------------------------------------------------

output "twingate_remote_network_id" {
  description = "Twingate remote network ID"
  value       = var.enable_twingate ? module.twingate[0].remote_network_id : null
}

output "twingate_connector_ips" {
  description = "Twingate connector private IPs"
  value       = var.enable_twingate ? module.twingate[0].vm_private_ips : []
}

# -----------------------------------------------------------------------------
# Private DNS
# -----------------------------------------------------------------------------

output "private_dns_zone_id" {
  description = "Private DNS zone ID"
  value       = var.private_dns_zone_name != "" ? module.private_dns[0].zone_id : null
}

output "private_dns_zone_name" {
  description = "Private DNS zone name"
  value       = var.private_dns_zone_name != "" ? module.private_dns[0].zone_name : null
}

output "private_dns_a_records" {
  description = "Map of A record names to their FQDNs"
  value       = var.private_dns_zone_name != "" ? module.private_dns[0].a_records : {}
}

output "private_dns_cname_records" {
  description = "Map of CNAME record names to their FQDNs"
  value       = var.private_dns_zone_name != "" ? module.private_dns[0].cname_records : {}
}

# -----------------------------------------------------------------------------
# vWAN Connection
# -----------------------------------------------------------------------------

output "vwan_connection_id" {
  description = "vWAN connection ID"
  value       = var.enable_vwan_connection ? module.vwan_connection[0].id : null
}

output "vwan_connection_name" {
  description = "vWAN connection name"
  value       = var.enable_vwan_connection ? module.vwan_connection[0].name : null
}
