# Operations Key Vault
#
# Provides centralized secret storage for operational secrets used across
# all environments. Secrets stored here are read by other layers via data
# sources, avoiding the need to pass secrets via CLI variables.
#
# Secrets to store (manually after creation):
# - twingate-api-token: Twingate API token for connector deployment
# - <other operational secrets as needed>

resource "azurerm_key_vault" "operations" {
  count = var.create_operations_key_vault ? 1 : 0

  name                = var.operations_key_vault_name
  location            = azurerm_resource_group.tfstate.location
  resource_group_name = azurerm_resource_group.tfstate.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  # Security settings
  enabled_for_deployment          = false
  enabled_for_disk_encryption     = false
  enabled_for_template_deployment = false
  rbac_authorization_enabled      = true
  purge_protection_enabled        = var.operations_key_vault_purge_protection
  soft_delete_retention_days      = var.operations_key_vault_soft_delete_days

  # Network ACLs - allow all by default (can be restricted)
  network_acls {
    default_action = var.restrict_network_access ? "Deny" : "Allow"
    bypass         = "AzureServices"
    ip_rules       = var.allowed_ip_ranges
  }

  tags = merge(var.tags, {
    Purpose   = "operational-secrets"
    ManagedBy = "terraform-management"
  })
}

# Grant the current user/service principal full access to manage secrets
resource "azurerm_role_assignment" "operations_kv_admin" {
  count = var.create_operations_key_vault ? 1 : 0

  scope                = azurerm_key_vault.operations[0].id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Data source for current client config (tenant and object ID)
data "azurerm_client_config" "current" {}
