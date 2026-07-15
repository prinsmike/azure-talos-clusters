# Data Sources
#
# Discovers network-and-security layer resources by name (no remote-state
# dependency), plus the shared Talos image published by the management layer.

# -----------------------------------------------------------------------------
# Network-and-security layer resource group
# -----------------------------------------------------------------------------

data "azurerm_resource_group" "network" {
  name = var.network_resource_group_name
}

# -----------------------------------------------------------------------------
# Shared Talos image (Compute Gallery in the management subscription, Change A)
#
# Consumed by every VMSS as source_image_id. Cross-subscription consumers need
# Reader on the gallery (granted in the management layer).
# -----------------------------------------------------------------------------

data "azurerm_shared_image_version" "talos" {
  provider            = azurerm.management
  name                = var.talos_image_version
  image_name          = var.talos_image_definition_name
  gallery_name        = var.talos_gallery_name
  resource_group_name = var.management_resource_group_name
}

# -----------------------------------------------------------------------------
# Container registry (management subscription) - optional ACR pull
# -----------------------------------------------------------------------------

data "azurerm_container_registry" "main" {
  provider            = azurerm.management
  count               = var.enable_acr_pull ? 1 : 0
  name                = var.container_registry_name
  resource_group_name = var.management_resource_group_name
}

resource "azurerm_role_assignment" "acr_pull_control_plane" {
  provider             = azurerm.management
  count                = var.enable_acr_pull ? 1 : 0
  scope                = data.azurerm_container_registry.main[0].id
  role_definition_name = "AcrPull"
  principal_id         = data.azurerm_user_assigned_identity.control_plane.principal_id
}

resource "azurerm_role_assignment" "acr_pull_workers" {
  provider             = azurerm.management
  count                = var.enable_acr_pull ? 1 : 0
  scope                = data.azurerm_container_registry.main[0].id
  role_definition_name = "AcrPull"
  principal_id         = data.azurerm_user_assigned_identity.workers.principal_id
}

# -----------------------------------------------------------------------------
# Network (from network-and-security layer)
# -----------------------------------------------------------------------------

data "azurerm_virtual_network" "vnet" {
  name                = "vnet-${var.project}-${var.environment}-${var.location_short}"
  resource_group_name = data.azurerm_resource_group.network.name
}

data "azurerm_subnet" "control_plane" {
  name                 = "snet-control-plane-${var.environment}"
  virtual_network_name = data.azurerm_virtual_network.vnet.name
  resource_group_name  = data.azurerm_resource_group.network.name
}

data "azurerm_subnet" "workers" {
  name                 = "snet-workers-${var.environment}"
  virtual_network_name = data.azurerm_virtual_network.vnet.name
  resource_group_name  = data.azurerm_resource_group.network.name
}

data "azurerm_subnet" "services" {
  name                 = "snet-services-${var.environment}"
  virtual_network_name = data.azurerm_virtual_network.vnet.name
  resource_group_name  = data.azurerm_resource_group.network.name
}

# -----------------------------------------------------------------------------
# NSGs (from network-and-security layer)
# -----------------------------------------------------------------------------

data "azurerm_network_security_group" "control_plane" {
  name                = "nsg-control-plane-${var.environment}-${var.location_short}"
  resource_group_name = data.azurerm_resource_group.network.name
}

data "azurerm_network_security_group" "workers" {
  name                = "nsg-workers-${var.environment}-${var.location_short}"
  resource_group_name = data.azurerm_resource_group.network.name
}

# -----------------------------------------------------------------------------
# Managed identities (from network-and-security layer)
# -----------------------------------------------------------------------------

data "azurerm_user_assigned_identity" "control_plane" {
  name                = "mi-talos-cp-${var.environment}"
  resource_group_name = data.azurerm_resource_group.network.name
}

data "azurerm_user_assigned_identity" "workers" {
  name                = "mi-talos-wkr-${var.environment}"
  resource_group_name = data.azurerm_resource_group.network.name
}

# Key Vault (for storing talosconfig / machine secrets)
data "azurerm_key_vault" "talos" {
  name                = "kv-talos-${var.environment}"
  resource_group_name = data.azurerm_resource_group.network.name
}

# cert-manager identity (if enabled in network-and-security)
data "azurerm_user_assigned_identity" "cert_manager" {
  count               = var.enable_cert_manager_federation ? 1 : 0
  name                = "id-cert-manager-${var.environment}"
  resource_group_name = data.azurerm_resource_group.network.name
}

# external-dns identity (if enabled in network-and-security, Change C)
data "azurerm_user_assigned_identity" "external_dns" {
  count               = var.enable_external_dns_federation ? 1 : 0
  name                = "id-external-dns-${var.environment}"
  resource_group_name = data.azurerm_resource_group.network.name
}
