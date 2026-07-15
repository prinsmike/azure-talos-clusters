# Backend configuration for remote state in Management subscription
# Uncomment and configure when ready for remote state
#
# NOTE: When using separate subscriptions, you must specify the
# subscription_id where the state storage account resides.
#
terraform {
  backend "azurerm" {
    subscription_id      = "00000000-0000-0000-0000-000000000000"
    resource_group_name  = "rg-talos-ops"
    storage_account_name = "sttalosstate"
    container_name       = "tfstate"
    key                  = "talos-dev-network-and-security.tfstate"
  }
}
