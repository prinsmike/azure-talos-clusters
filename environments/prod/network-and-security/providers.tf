terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    twingate = {
      source  = "Twingate/twingate"
      version = "~> 4.2"
    }
  }
}

# Resolve management subscription - defaults to environment subscription if not specified
locals {
  effective_management_subscription_id = coalesce(var.management_subscription_id, var.azure_subscription_id)
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }

  subscription_id = var.azure_subscription_id
}

# Provider for accessing management-layer resources in the management subscription
# Used for Operations Key Vault, ACR, and other shared resources
provider "azurerm" {
  alias = "management"

  features {}

  subscription_id = local.effective_management_subscription_id
}

provider "twingate" {
  api_token = local.twingate_api_token
  network   = local.twingate_network
}
