# Terraform Backend Configuration for the Management layer
#
# NOTE: This backend configuration is applied AFTER the initial deployment,
# because this layer creates the very storage account that stores its own state.
# The bootstrap-of-the-bootstrap process:
#   1. Deploy with local state (comment out this block)
#   2. Run `terraform apply` to create the storage account
#   3. Uncomment this block
#   4. Run `terraform init -migrate-state` to move state to the remote backend
#
# This lets the management state benefit from:
#   - Blob versioning (state history)
#   - Soft delete (30-day recovery)
#   - Geo-redundant storage (GRS)
#
# The resource_group_name / storage_account_name below MUST match the values you
# set for var.resource_group_name / var.storage_account_name.

terraform {
  backend "azurerm" {
    resource_group_name  = "rg-talos-ops"
    storage_account_name = "sttalosstate" # globally unique — change to your own
    container_name       = "tfstate"
    key                  = "management.tfstate"
  }
}
