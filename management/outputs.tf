# -----------------------------------------------------------------------------
# Resource Group
# -----------------------------------------------------------------------------

output "resource_group_name" {
  description = "Resource group name"
  value       = azurerm_resource_group.tfstate.name
}

output "resource_group_id" {
  description = "Resource group ID"
  value       = azurerm_resource_group.tfstate.id
}

# -----------------------------------------------------------------------------
# Storage Account
# -----------------------------------------------------------------------------

output "storage_account_name" {
  description = "Storage account name"
  value       = azurerm_storage_account.tfstate.name
}

output "storage_account_id" {
  description = "Storage account ID"
  value       = azurerm_storage_account.tfstate.id
}

output "storage_account_primary_access_key" {
  description = "Storage account primary access key"
  value       = azurerm_storage_account.tfstate.primary_access_key
  sensitive   = true
}

output "container_name" {
  description = "Blob container name"
  value       = azurerm_storage_container.tfstate.name
}

# -----------------------------------------------------------------------------
# Container Registry
# -----------------------------------------------------------------------------

output "container_registry_name" {
  description = "Container registry name"
  value       = var.create_container_registry ? azurerm_container_registry.main[0].name : null
}

output "container_registry_id" {
  description = "Container registry ID"
  value       = var.create_container_registry ? azurerm_container_registry.main[0].id : null
}

output "container_registry_login_server" {
  description = "Container registry login server URL"
  value       = var.create_container_registry ? azurerm_container_registry.main[0].login_server : null
}

output "container_registry_admin_username" {
  description = "Container registry admin username"
  value       = var.create_container_registry && var.container_registry_admin_enabled ? azurerm_container_registry.main[0].admin_username : null
  sensitive   = true
}

output "container_registry_admin_password" {
  description = "Container registry admin password"
  value       = var.create_container_registry && var.container_registry_admin_enabled ? azurerm_container_registry.main[0].admin_password : null
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Operations Key Vault
# -----------------------------------------------------------------------------

output "operations_key_vault_name" {
  description = "Operations Key Vault name"
  value       = var.create_operations_key_vault ? azurerm_key_vault.operations[0].name : null
}

output "operations_key_vault_id" {
  description = "Operations Key Vault ID"
  value       = var.create_operations_key_vault ? azurerm_key_vault.operations[0].id : null
}

output "operations_key_vault_uri" {
  description = "Operations Key Vault URI"
  value       = var.create_operations_key_vault ? azurerm_key_vault.operations[0].vault_uri : null
}

# -----------------------------------------------------------------------------
# Backend Configuration Helper
# -----------------------------------------------------------------------------

output "backend_config" {
  description = "Backend configuration for other Terraform projects"
  value = {
    resource_group_name  = azurerm_resource_group.tfstate.name
    storage_account_name = azurerm_storage_account.tfstate.name
    container_name       = azurerm_storage_container.tfstate.name
  }
}

output "backend_config_example" {
  description = "Example backend configuration block"
  value       = <<-EOT
    terraform {
      backend "azurerm" {
        resource_group_name  = "${azurerm_resource_group.tfstate.name}"
        storage_account_name = "${azurerm_storage_account.tfstate.name}"
        container_name       = "${azurerm_storage_container.tfstate.name}"
        key                  = "your-project.tfstate"
      }
    }
  EOT
}

# -----------------------------------------------------------------------------
# vWAN (Optional)
# -----------------------------------------------------------------------------

output "vwan_id" {
  description = "vWAN ID"
  value       = var.enable_vwan ? module.vwan[0].vwan_id : null
}

output "vwan_hub_id" {
  description = "vWAN Hub ID"
  value       = var.enable_vwan ? module.vwan[0].hub_id : null
}

output "vwan_hub_default_route_table_id" {
  description = "vWAN Hub default route table ID"
  value       = var.enable_vwan ? module.vwan[0].hub_default_route_table_id : null
}

output "vwan_firewall_private_ip" {
  description = "vWAN Firewall private IP"
  value       = var.enable_vwan ? module.vwan[0].firewall_private_ip : null
}

output "vwan_firewall_public_ip" {
  description = "vWAN Firewall public IP"
  value       = var.enable_vwan ? module.vwan[0].firewall_public_ip : null
}
