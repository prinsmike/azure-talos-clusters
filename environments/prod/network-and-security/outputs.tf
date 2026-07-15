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
# Public DNS
# -----------------------------------------------------------------------------

output "public_dns_zones" {
  description = "Map of public DNS zone names to their details"
  value = {
    for zone_name, zone in module.public_dns : zone_name => {
      zone_id      = zone.zone_id
      name_servers = zone.name_servers
    }
  }
}

output "public_dns_zones_nameservers" {
  description = "Nameservers for each public DNS zone - configure these at your registrar"
  value = {
    for zone_name, zone in module.public_dns : zone_name => zone.name_servers
  }
}

# -----------------------------------------------------------------------------
# Internal DNS (private zones)
# -----------------------------------------------------------------------------

output "internal_apex_dns_zone_id" {
  description = "Internal apex private DNS zone ID (e.g. int.example.com)"
  value       = var.internal_apex_zone_name != "" ? module.internal_apex_dns[0].zone_id : null
}

output "internal_apex_dns_zone_name" {
  description = "Internal apex private DNS zone name"
  value       = var.internal_apex_zone_name != "" ? module.internal_apex_dns[0].zone_name : null
}

output "internal_apps_dns_zone_id" {
  description = "Internal apps private DNS zone ID (records managed by external-dns)"
  value       = var.internal_apps_zone_name != "" ? module.internal_apps_dns[0].zone_id : null
}

output "internal_apps_dns_zone_name" {
  description = "Internal apps private DNS zone name"
  value       = var.internal_apps_zone_name != "" ? module.internal_apps_dns[0].zone_name : null
}

# -----------------------------------------------------------------------------
# cert-manager Workload Identity
# -----------------------------------------------------------------------------

output "cert_manager_identity_id" {
  description = "cert-manager managed identity ID"
  value       = var.enable_cert_manager_identity ? azurerm_user_assigned_identity.cert_manager[0].id : null
}

output "cert_manager_identity_client_id" {
  description = "cert-manager managed identity client ID (for ClusterIssuer config)"
  value       = var.enable_cert_manager_identity ? azurerm_user_assigned_identity.cert_manager[0].client_id : null
}

output "cert_manager_identity_principal_id" {
  description = "cert-manager managed identity principal ID"
  value       = var.enable_cert_manager_identity ? azurerm_user_assigned_identity.cert_manager[0].principal_id : null
}

# -----------------------------------------------------------------------------
# external-dns Workload Identity
# -----------------------------------------------------------------------------

output "external_dns_identity_id" {
  description = "external-dns managed identity ID"
  value       = var.enable_external_dns_identity ? azurerm_user_assigned_identity.external_dns[0].id : null
}

output "external_dns_identity_client_id" {
  description = "external-dns managed identity client ID (annotate the external-dns ServiceAccount with this)"
  value       = var.enable_external_dns_identity ? azurerm_user_assigned_identity.external_dns[0].client_id : null
}

output "external_dns_identity_principal_id" {
  description = "external-dns managed identity principal ID"
  value       = var.enable_external_dns_identity ? azurerm_user_assigned_identity.external_dns[0].principal_id : null
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
