# Twingate Connectors
#
# Deploys Twingate connectors for secure remote access using VMs.
# Disabled by default; set enable_twingate = true and provide credentials.

module "twingate" {
  count  = var.enable_twingate ? 1 : 0
  source = "../../../modules/twingate-connector-vm"

  name                  = "twingate-${local.resource_prefix}"
  location              = var.location
  resource_group_name   = azurerm_resource_group.network.name
  subnet_id             = module.vnet.subnet_ids["snet-connector-vms-${var.environment}"]
  twingate_network_name = "${var.environment}-talos"
  twingate_account      = local.twingate_network # Account name (your Twingate account name, e.g. the subdomain of <account>.twingate.com)
  connector_count       = var.twingate_connector_count
  ssh_public_key        = local.twingate_ssh_public_key
  vm_size               = var.twingate_vm_size

  # Twingate Resources (network access)
  twingate_resources = var.twingate_resources
  twingate_group_ids = var.twingate_group_ids

  tags = merge(var.tags, {
    Layer = "network-and-security"
  })
}
