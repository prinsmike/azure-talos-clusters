# Backend configuration for remote state in Management subscription
# Uncomment and configure when ready for remote state
#
# NOTE: When using separate subscriptions, you must specify the
# subscription_id where the state storage account resides.
#
# terraform {
#   backend "azurerm" {
#     subscription_id      = "<management-subscription-id>"
#     resource_group_name  = "rg-talos-ops"
#     storage_account_name = "sttalosstate"
#     container_name       = "tfstate"
#     key                  = "talos-prod-network-and-security.tfstate"
#   }
# }
