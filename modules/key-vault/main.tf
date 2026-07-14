# Key Vault Module
#
# Creates an Azure Key Vault with configurable access policies.
# Uses only external azurerm_key_vault_access_policy resources to avoid conflicts.

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "this" {
  name                       = var.name
  location                   = var.location
  resource_group_name        = var.resource_group_name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = var.sku_name
  soft_delete_retention_days = var.soft_delete_retention_days
  purge_protection_enabled   = var.purge_protection_enabled

  network_acls {
    default_action = var.network_acls_default_action
    bypass         = "AzureServices"
    ip_rules       = var.allowed_ip_ranges
  }

  # No inline access_policy block - all policies managed via azurerm_key_vault_access_policy

  tags = var.tags
}

# Access policy for Terraform service principal (current user running terraform)
resource "azurerm_key_vault_access_policy" "terraform" {
  key_vault_id = azurerm_key_vault.this.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Get", "List", "Set", "Delete", "Purge", "Recover", "Backup", "Restore"
  ]

  key_permissions = [
    "Get", "List", "Create", "Delete", "Purge", "Recover"
  ]

  certificate_permissions = [
    "Get", "List", "Create", "Delete", "Purge", "Recover"
  ]
}

# Additional access policies for managed identities and other principals
resource "azurerm_key_vault_access_policy" "additional" {
  for_each = { for policy in var.access_policies : policy.name => policy }

  key_vault_id = azurerm_key_vault.this.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = each.value.object_id

  secret_permissions      = each.value.secret_permissions
  key_permissions         = each.value.key_permissions
  certificate_permissions = each.value.certificate_permissions
}
