# Identity and Access Management
#
# Managed identities and role assignments for cluster nodes.
# Security: Use custom least-privilege roles when use_least_privilege_roles = true

# Control Plane Managed Identity
resource "azurerm_user_assigned_identity" "control_plane" {
  name                = "mi-talos-cp-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.network.name

  tags = var.tags
}

# Workers Managed Identity
resource "azurerm_user_assigned_identity" "workers" {
  name                = "mi-talos-wkr-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.network.name

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Custom Least-Privilege Roles (when enabled)
# See security-hardening.md Issue #3 for details
# -----------------------------------------------------------------------------

module "custom_roles" {
  count  = var.use_least_privilege_roles ? 1 : 0
  source = "../../../modules/custom-roles"

  environment = var.environment
  scope       = azurerm_resource_group.network.id
}

# -----------------------------------------------------------------------------
# Role Assignments - Legacy (VM/Network Contributor - broad permissions)
# Used when use_least_privilege_roles = false
# -----------------------------------------------------------------------------

# Control Plane - VM Contributor (for cloud provider)
resource "azurerm_role_assignment" "cp_vm_contributor" {
  count                = var.use_least_privilege_roles ? 0 : 1
  scope                = azurerm_resource_group.network.id
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = azurerm_user_assigned_identity.control_plane.principal_id
}

# Workers - VM Contributor
resource "azurerm_role_assignment" "workers_vm_contributor" {
  count                = var.use_least_privilege_roles ? 0 : 1
  scope                = azurerm_resource_group.network.id
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = azurerm_user_assigned_identity.workers.principal_id
}

# Control Plane - Network Contributor (for load balancers)
resource "azurerm_role_assignment" "cp_network_contributor" {
  count                = var.use_least_privilege_roles ? 0 : 1
  scope                = module.vnet.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.control_plane.principal_id
}

# Workers - Network Contributor
resource "azurerm_role_assignment" "workers_network_contributor" {
  count                = var.use_least_privilege_roles ? 0 : 1
  scope                = module.vnet.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.workers.principal_id
}

# -----------------------------------------------------------------------------
# Role Assignments - Least Privilege (custom roles - restricted permissions)
# Used when use_least_privilege_roles = true
# -----------------------------------------------------------------------------

# Control Plane - Custom K8s Cloud Provider role
resource "azurerm_role_assignment" "cp_k8s_cloud_provider" {
  count              = var.use_least_privilege_roles ? 1 : 0
  scope              = azurerm_resource_group.network.id
  role_definition_id = module.custom_roles[0].control_plane_role_id
  principal_id       = azurerm_user_assigned_identity.control_plane.principal_id
}

# Control Plane - VNet scope for load balancer operations
resource "azurerm_role_assignment" "cp_k8s_cloud_provider_vnet" {
  count              = var.use_least_privilege_roles ? 1 : 0
  scope              = module.vnet.id
  role_definition_id = module.custom_roles[0].control_plane_role_id
  principal_id       = azurerm_user_assigned_identity.control_plane.principal_id
}

# Workers - Custom K8s Cloud Provider role (read-only)
resource "azurerm_role_assignment" "workers_k8s_cloud_provider" {
  count              = var.use_least_privilege_roles ? 1 : 0
  scope              = azurerm_resource_group.network.id
  role_definition_id = module.custom_roles[0].worker_role_id
  principal_id       = azurerm_user_assigned_identity.workers.principal_id
}
