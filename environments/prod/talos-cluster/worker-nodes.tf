# Worker Nodes
#
# Production worker pools: a general pool and a higher-spec compute pool.
# Add further pools (memory-optimized, GPU, ...) by duplicating a block.

# -----------------------------------------------------------------------------
# General Worker Pool
#
# General-purpose workers for platform and application workloads.
# -----------------------------------------------------------------------------

module "workers_general" {
  source = "../../../modules/vmss"

  name                = "${local.cluster_name_prefix}-workers-general"
  location            = var.location
  resource_group_name = azurerm_resource_group.cluster.name

  vm_size   = var.general_pool_vm_size
  instances = var.general_pool_instance_count
  zones     = ["1", "2", "3"]

  single_placement_group = false
  overprovision          = false
  upgrade_mode           = "Manual"

  image_id       = data.azurerm_shared_image_version.talos.id
  machine_config = module.talos_config.worker_config

  os_disk_type    = "Premium_ZRS"
  os_disk_size_gb = var.general_pool_os_disk_size_gb

  subnet_id           = data.azurerm_subnet.workers.id
  nsg_id              = data.azurerm_network_security_group.workers.id
  managed_identity_id = data.azurerm_user_assigned_identity.workers.id

  enable_boot_diagnostics = true

  tags = merge(var.tags, {
    Component    = "workers"
    WorkloadType = "general"
  })
}

# -----------------------------------------------------------------------------
# Compute Worker Pool
#
# Higher-spec workers for compute-intensive workloads. Use Kubernetes node
# labels / taints (applied via the Talos worker config or kubectl) to steer
# specific workloads here.
# -----------------------------------------------------------------------------

module "workers_compute" {
  source = "../../../modules/vmss"

  name                = "${local.cluster_name_prefix}-workers-compute"
  location            = var.location
  resource_group_name = azurerm_resource_group.cluster.name

  vm_size   = var.compute_pool_vm_size
  instances = var.compute_pool_instance_count
  zones     = ["1", "2", "3"]

  single_placement_group = false
  overprovision          = false
  upgrade_mode           = "Manual"

  image_id       = data.azurerm_shared_image_version.talos.id
  machine_config = module.talos_config.worker_config

  os_disk_type    = "Premium_ZRS"
  os_disk_size_gb = var.compute_pool_os_disk_size_gb

  subnet_id           = data.azurerm_subnet.workers.id
  nsg_id              = data.azurerm_network_security_group.workers.id
  managed_identity_id = data.azurerm_user_assigned_identity.workers.id

  enable_boot_diagnostics = true

  tags = merge(var.tags, {
    Component    = "workers"
    WorkloadType = "compute"
  })
}

# Note: cluster autoscaling is configured via the Azure CLI after deployment,
# because the Terraform provider currently returns a 400 on autoscale settings
# for these scale sets. Example:
#
# az monitor autoscale create \
#   --resource-group rg-talos-prod-eastus \
#   --resource vmss-talos-prod-workers-general \
#   --resource-type Microsoft.Compute/virtualMachineScaleSets \
#   --name autoscale-vmss-talos-prod-general \
#   --min-count 2 --max-count 6 --count 2
