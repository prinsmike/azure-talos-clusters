# Identity and Access Management - Cluster Layer
#
# Role assignments for the control plane managed identity on the cluster
# resource group. These are required for the Azure Cloud Controller Manager
# (CCM) to manage nodes and create load balancers.
#
# The managed identities are created in the network-and-security layer, but
# they need additional permissions on the cluster resource group where the
# VMSS and load balancers are deployed.

# -----------------------------------------------------------------------------
# Azure CCM Role Assignments on the Cluster Resource Group
# -----------------------------------------------------------------------------

# Control Plane - Virtual Machine Contributor on the cluster RG
# Required for Azure CCM to read VMSS instances and set provider IDs on nodes.
resource "azurerm_role_assignment" "cp_vm_contributor_cluster" {
  scope                = azurerm_resource_group.cluster.id
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = data.azurerm_user_assigned_identity.control_plane.principal_id
}

# Control Plane - Network Contributor on the cluster RG
# Required for Azure CCM to create and manage load balancers for Kubernetes
# services and manage frontend IP configurations.
resource "azurerm_role_assignment" "cp_network_contributor_cluster" {
  scope                = azurerm_resource_group.cluster.id
  role_definition_name = "Network Contributor"
  principal_id         = data.azurerm_user_assigned_identity.control_plane.principal_id
}
