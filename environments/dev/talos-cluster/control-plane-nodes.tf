# Control Plane Nodes
#
# Single control plane node for the dev environment.

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
# Control Plane VMSS (single node for dev)
# -----------------------------------------------------------------------------

module "control_plane" {
  source = "../../../modules/vmss"

  name                = "${local.cluster_name_prefix}-cp"
  location            = var.location
  resource_group_name = azurerm_resource_group.cluster.name

  vm_size   = var.control_plane_vm_size
  instances = 1
  zones     = ["1"]

  single_placement_group = true
  overprovision          = false

  image_id       = data.azurerm_shared_image_version.talos.id
  machine_config = module.talos_config.control_plane_configs["1"]

  os_disk_type    = "Premium_LRS"
  os_disk_size_gb = var.control_plane_os_disk_size_gb

  subnet_id           = data.azurerm_subnet.control_plane.id
  nsg_id              = data.azurerm_network_security_group.control_plane.id
  managed_identity_id = data.azurerm_user_assigned_identity.control_plane.id

  load_balancer_backend_pool_ids = [azurerm_lb_backend_address_pool.control_plane.id]

  tags = merge(var.tags, {
    Component = "control-plane"
  })
}
