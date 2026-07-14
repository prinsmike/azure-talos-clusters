# vWAN Infrastructure (Optional)
#
# Deploys Azure Virtual WAN with a Secured Hub (Azure Firewall) for testing
# vWAN connectivity. This mimics the central/management vWAN setup that a larger
# organization would run in production, into which each environment's spoke VNet
# connects (see modules/vwan-connection).
#
# Enable with: terraform apply -var="enable_vwan=true"

module "vwan" {
  source = "../modules/vwan"
  count  = var.enable_vwan ? 1 : 0

  name                = "vwan-talos-mgmt"
  location            = var.location
  resource_group_name = azurerm_resource_group.tfstate.name
  hub_address_prefix  = var.vwan_hub_address_prefix
  firewall_sku        = var.vwan_firewall_sku
  dnat_rules          = var.vwan_dnat_rules

  tags = merge(var.tags, {
    Component = "vwan"
  })
}
