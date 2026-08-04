terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.5"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# Resolve the management subscription - defaults to this environment's
# subscription when management_subscription_id is left empty.
locals {
  effective_management_subscription_id = coalesce(var.management_subscription_id, var.azure_subscription_id)
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
    virtual_machine_scale_set {
      force_delete                 = false
      roll_instances_when_required = false
    }
  }

  subscription_id = var.azure_subscription_id
}

# Provider for management-subscription resources: the shared Talos image
# gallery (Change A) and the shared container registry (optional ACR pull).
provider "azurerm" {
  alias = "management"

  features {}

  subscription_id = local.effective_management_subscription_id
}
