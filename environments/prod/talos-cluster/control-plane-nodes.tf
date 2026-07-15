# Control Plane Nodes
#
# 3 control plane nodes across availability zones for an HA production cluster.
# One VMSS per zone so each node consumes its per-zone Talos machine config.

locals {
  cluster_name_prefix = "vmss-${var.cluster_name}"
}

# Cluster resource group
resource "azurerm_resource_group" "cluster" {
  name     = "rg-${var.cluster_name}-${var.location_short}"
  location = var.location

  tags = merge(var.tags, {
    Layer = "talos-cluster"
  })
}

# -----------------------------------------------------------------------------
# Internal Load Balancer for the API server
# -----------------------------------------------------------------------------

resource "azurerm_lb" "api_server" {
  name                = "lb-${var.cluster_name}-api"
  location            = var.location
  resource_group_name = azurerm_resource_group.cluster.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = "api-frontend"
    subnet_id                     = data.azurerm_subnet.services.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.api_server_lb_ip
  }

  tags = var.tags
}

resource "azurerm_lb_backend_address_pool" "control_plane" {
  name            = "control-plane-pool"
  loadbalancer_id = azurerm_lb.api_server.id
}

resource "azurerm_lb_probe" "api_server" {
  loadbalancer_id = azurerm_lb.api_server.id
  name            = "api-probe"
  port            = 6443
  protocol        = "Tcp"
}

resource "azurerm_lb_rule" "api_server" {
  loadbalancer_id                = azurerm_lb.api_server.id
  name                           = "api-rule"
  protocol                       = "Tcp"
  frontend_port                  = 6443
  backend_port                   = 6443
  frontend_ip_configuration_name = "api-frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.control_plane.id]
  probe_id                       = azurerm_lb_probe.api_server.id
  floating_ip_enabled            = false
  idle_timeout_in_minutes        = 4
}

resource "azurerm_lb_rule" "talos_api" {
  loadbalancer_id                = azurerm_lb.api_server.id
  name                           = "talos-api-rule"
  protocol                       = "Tcp"
  frontend_port                  = 50000
  backend_port                   = 50000
  frontend_ip_configuration_name = "api-frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.control_plane.id]
  probe_id                       = azurerm_lb_probe.api_server.id
  floating_ip_enabled            = false
  idle_timeout_in_minutes        = 4
}

# Trustd probe and rule - needed for worker certificate signing
resource "azurerm_lb_probe" "trustd" {
  loadbalancer_id = azurerm_lb.api_server.id
  name            = "trustd-probe"
  port            = 50001
  protocol        = "Tcp"
}

resource "azurerm_lb_rule" "trustd" {
  loadbalancer_id                = azurerm_lb.api_server.id
  name                           = "trustd-rule"
  protocol                       = "Tcp"
  frontend_port                  = 50001
  backend_port                   = 50001
  frontend_ip_configuration_name = "api-frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.control_plane.id]
  probe_id                       = azurerm_lb_probe.trustd.id
  floating_ip_enabled            = false
  idle_timeout_in_minutes        = 4
}

# -----------------------------------------------------------------------------
# Control Plane VMSS - Zone 1
# -----------------------------------------------------------------------------

module "control_plane_z1" {
  source = "../../../modules/vmss"

  name                = "${local.cluster_name_prefix}-cp-z1"
  location            = var.location
  resource_group_name = azurerm_resource_group.cluster.name

  vm_size   = var.control_plane_vm_size
  instances = 1
  zones     = ["1"]

  single_placement_group = true
  overprovision          = false
  upgrade_mode           = "Manual"

  image_id       = data.azurerm_shared_image_version.talos.id
  machine_config = module.talos_config.control_plane_configs["1"]

  os_disk_type    = "Premium_ZRS"
  os_disk_size_gb = var.control_plane_os_disk_size_gb

  subnet_id           = data.azurerm_subnet.control_plane.id
  nsg_id              = data.azurerm_network_security_group.control_plane.id
  managed_identity_id = data.azurerm_user_assigned_identity.control_plane.id

  load_balancer_backend_pool_ids = [azurerm_lb_backend_address_pool.control_plane.id]

  enable_boot_diagnostics = true

  tags = merge(var.tags, {
    Component = "control-plane"
    Zone      = "1"
  })
}

# -----------------------------------------------------------------------------
# Control Plane VMSS - Zone 2
# -----------------------------------------------------------------------------

module "control_plane_z2" {
  source = "../../../modules/vmss"

  name                = "${local.cluster_name_prefix}-cp-z2"
  location            = var.location
  resource_group_name = azurerm_resource_group.cluster.name

  vm_size   = var.control_plane_vm_size
  instances = 1
  zones     = ["2"]

  single_placement_group = true
  overprovision          = false
  upgrade_mode           = "Manual"

  image_id       = data.azurerm_shared_image_version.talos.id
  machine_config = module.talos_config.control_plane_configs["2"]

  os_disk_type    = "Premium_ZRS"
  os_disk_size_gb = var.control_plane_os_disk_size_gb

  subnet_id           = data.azurerm_subnet.control_plane.id
  nsg_id              = data.azurerm_network_security_group.control_plane.id
  managed_identity_id = data.azurerm_user_assigned_identity.control_plane.id

  load_balancer_backend_pool_ids = [azurerm_lb_backend_address_pool.control_plane.id]

  enable_boot_diagnostics = true

  tags = merge(var.tags, {
    Component = "control-plane"
    Zone      = "2"
  })
}

# -----------------------------------------------------------------------------
# Control Plane VMSS - Zone 3
# -----------------------------------------------------------------------------

module "control_plane_z3" {
  source = "../../../modules/vmss"

  name                = "${local.cluster_name_prefix}-cp-z3"
  location            = var.location
  resource_group_name = azurerm_resource_group.cluster.name

  vm_size   = var.control_plane_vm_size
  instances = 1
  zones     = ["3"]

  single_placement_group = true
  overprovision          = false
  upgrade_mode           = "Manual"

  image_id       = data.azurerm_shared_image_version.talos.id
  machine_config = module.talos_config.control_plane_configs["3"]

  os_disk_type    = "Premium_ZRS"
  os_disk_size_gb = var.control_plane_os_disk_size_gb

  subnet_id           = data.azurerm_subnet.control_plane.id
  nsg_id              = data.azurerm_network_security_group.control_plane.id
  managed_identity_id = data.azurerm_user_assigned_identity.control_plane.id

  load_balancer_backend_pool_ids = [azurerm_lb_backend_address_pool.control_plane.id]

  enable_boot_diagnostics = true

  tags = merge(var.tags, {
    Component = "control-plane"
    Zone      = "3"
  })
}
