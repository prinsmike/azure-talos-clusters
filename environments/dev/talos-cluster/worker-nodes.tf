# Worker Nodes
#
# Single worker pool for the dev environment.

module "workers" {
  source = "../../../modules/vmss"

  name                = "${local.cluster_name_prefix}-workers"
  location            = var.location
  resource_group_name = azurerm_resource_group.cluster.name

  vm_size   = var.worker_vm_size
  instances = var.worker_instance_count
  zones     = ["1", "2", "3"]

  single_placement_group = false
  overprovision          = false
  upgrade_mode           = "Manual"

  image_id       = data.azurerm_shared_image_version.talos.id
  machine_config = module.talos_config.worker_config

  os_disk_type    = "Premium_LRS"
  os_disk_size_gb = var.worker_os_disk_size_gb

  subnet_id           = data.azurerm_subnet.workers.id
  nsg_id              = data.azurerm_network_security_group.workers.id
  managed_identity_id = data.azurerm_user_assigned_identity.workers.id

  enable_boot_diagnostics = true

  tags = merge(var.tags, {
    Component = "workers"
  })
}
