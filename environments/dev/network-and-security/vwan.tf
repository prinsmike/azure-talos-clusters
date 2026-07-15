# vWAN Connection (Optional)
#
# Connects the environment VNet to a management vWAN Hub.
# Used for testing vWAN connectivity or connecting to a central management vWAN.
#
# Enable with:
#   terraform apply \
#     -var="enable_vwan_connection=true" \
#     -var="vwan_hub_id=<hub-resource-id>"

module "vwan_connection" {
  source = "../../../modules/vwan-connection"
  count  = var.enable_vwan_connection ? 1 : 0

  name                      = "vhc-${local.resource_prefix}-${var.location_short}"
  vwan_hub_id               = var.vwan_hub_id
  vnet_id                   = module.vnet.id
  internet_security_enabled = var.vwan_internet_security_enabled
}
