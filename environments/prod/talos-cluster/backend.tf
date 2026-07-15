# Remote state backend (management subscription).
#
# Uncomment and set your own values once the management layer has created the
# state storage account. When the state account lives in a different
# subscription from this environment, set subscription_id explicitly.
#
# terraform {
#   backend "azurerm" {
#     subscription_id      = "00000000-0000-0000-0000-000000000000"
#     resource_group_name  = "rg-talos-ops"
#     storage_account_name = "sttalosstate"
#     container_name       = "tfstate"
#     key                  = "talos-prod-talos-cluster.tfstate"
#   }
# }
