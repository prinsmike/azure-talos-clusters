# Custom Azure Roles Module
#
# Least-privilege custom role definitions for Kubernetes cloud provider.
# See ADR-0002 and security-hardening.md for context.

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
  }
}

data "azurerm_subscription" "current" {}

# -----------------------------------------------------------------------------
# Kubernetes Cloud Provider Role (Control Plane)
# Minimal permissions for Azure Cloud Provider operations
# Reference: https://github.com/kubernetes-sigs/cloud-provider-azure/blob/master/docs/cloud-provider-config.md
# -----------------------------------------------------------------------------

resource "azurerm_role_definition" "k8s_cloud_provider_cp" {
  name        = "Kubernetes Cloud Provider - Control Plane (${var.environment})"
  scope       = var.scope
  description = "Minimal permissions for Kubernetes Azure Cloud Provider on control plane nodes"

  permissions {
    actions = [
      # VM/VMSS read operations (for node discovery)
      "Microsoft.Compute/virtualMachines/read",
      "Microsoft.Compute/virtualMachineScaleSets/read",
      "Microsoft.Compute/virtualMachineScaleSets/virtualMachines/read",
      "Microsoft.Compute/virtualMachineScaleSets/virtualMachines/instanceView/read",

      # Load balancer operations (for Service type LoadBalancer)
      "Microsoft.Network/loadBalancers/read",
      "Microsoft.Network/loadBalancers/write",
      "Microsoft.Network/loadBalancers/delete",
      "Microsoft.Network/loadBalancers/backendAddressPools/read",
      "Microsoft.Network/loadBalancers/backendAddressPools/write",
      "Microsoft.Network/loadBalancers/backendAddressPools/join/action",

      # Public IP operations (for LoadBalancer services)
      "Microsoft.Network/publicIPAddresses/read",
      "Microsoft.Network/publicIPAddresses/write",
      "Microsoft.Network/publicIPAddresses/delete",
      "Microsoft.Network/publicIPAddresses/join/action",

      # Network interface read (for node IP discovery)
      "Microsoft.Network/networkInterfaces/read",

      # Network security group operations (for LoadBalancer health probes)
      "Microsoft.Network/networkSecurityGroups/read",

      # Resource group read (for resource discovery and tags)
      "Microsoft.Resources/subscriptions/resourceGroups/read",

      # Availability zones read
      "Microsoft.Compute/locations/*/read"
    ]
    not_actions = []
  }

  assignable_scopes = [var.scope]
}

# -----------------------------------------------------------------------------
# Kubernetes Cloud Provider Role (Workers)
# Even more restricted - workers don't manage load balancers
# -----------------------------------------------------------------------------

resource "azurerm_role_definition" "k8s_cloud_provider_worker" {
  name        = "Kubernetes Cloud Provider - Worker (${var.environment})"
  scope       = var.scope
  description = "Minimal permissions for Kubernetes Azure Cloud Provider on worker nodes"

  permissions {
    actions = [
      # VM/VMSS read operations (for node discovery)
      "Microsoft.Compute/virtualMachines/read",
      "Microsoft.Compute/virtualMachineScaleSets/read",
      "Microsoft.Compute/virtualMachineScaleSets/virtualMachines/read",
      "Microsoft.Compute/virtualMachineScaleSets/virtualMachines/instanceView/read",

      # Network interface read (for node IP discovery)
      "Microsoft.Network/networkInterfaces/read",

      # Resource group read (for resource discovery)
      "Microsoft.Resources/subscriptions/resourceGroups/read",

      # Availability zones read
      "Microsoft.Compute/locations/*/read"
    ]
    not_actions = []
  }

  assignable_scopes = [var.scope]
}
