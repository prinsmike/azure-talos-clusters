# Data sources for referencing existing resources

data "azurerm_client_config" "current" {}

# -----------------------------------------------------------------------------
# Operations Key Vault (from the Management layer in Management subscription)
# Used to read operational secrets like Twingate API token
# -----------------------------------------------------------------------------

data "azurerm_key_vault" "operations" {
  provider = azurerm.management
  count    = var.use_operations_key_vault ? 1 : 0

  name                = var.operations_key_vault_name
  resource_group_name = var.operations_key_vault_resource_group
}

data "azurerm_key_vault_secret" "twingate_api_token" {
  provider = azurerm.management
  count    = var.use_operations_key_vault && var.enable_twingate ? 1 : 0

  name         = "twingate-api-token"
  key_vault_id = data.azurerm_key_vault.operations[0].id
}

data "azurerm_key_vault_secret" "twingate_network" {
  provider = azurerm.management
  count    = var.use_operations_key_vault && var.enable_twingate ? 1 : 0

  name         = "twingate-network"
  key_vault_id = data.azurerm_key_vault.operations[0].id
}

data "azurerm_key_vault_secret" "twingate_ssh_public_key" {
  provider = azurerm.management
  count    = var.use_operations_key_vault && var.enable_twingate ? 1 : 0

  name         = "twingate-ssh-public-key"
  key_vault_id = data.azurerm_key_vault.operations[0].id
}

# -----------------------------------------------------------------------------
# Local values for secret resolution
# Prefers Key Vault secrets over CLI variables when use_operations_key_vault=true
# -----------------------------------------------------------------------------

locals {
  twingate_api_token = var.use_operations_key_vault && var.enable_twingate ? (
    data.azurerm_key_vault_secret.twingate_api_token[0].value
  ) : var.twingate_api_token

  twingate_network = var.use_operations_key_vault && var.enable_twingate ? (
    data.azurerm_key_vault_secret.twingate_network[0].value
  ) : var.twingate_network

  twingate_ssh_public_key = var.use_operations_key_vault && var.enable_twingate ? (
    data.azurerm_key_vault_secret.twingate_ssh_public_key[0].value
  ) : var.twingate_ssh_public_key
}
