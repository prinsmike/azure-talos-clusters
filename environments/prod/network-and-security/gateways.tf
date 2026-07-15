# NAT Gateway
#
# Provides outbound internet access for cluster nodes.

module "nat_gateway" {
  source = "../../../modules/nat-gateway"

  name                = "nat-${var.environment}-${var.location_short}"
  public_ip_name      = "pip-nat-${var.environment}-${var.location_short}"
  location            = var.location
  resource_group_name = azurerm_resource_group.network.name

  zones = ["1", "2", "3"]

  # Associate with subnets that need outbound access (map of name -> ID)
  subnet_ids = {
    "snet-control-plane-${var.environment}" = module.vnet.subnet_ids["snet-control-plane-${var.environment}"]
    "snet-workers-${var.environment}"       = module.vnet.subnet_ids["snet-workers-${var.environment}"]
    "snet-services-${var.environment}"      = module.vnet.subnet_ids["snet-services-${var.environment}"]
  }

  tags = var.tags
}
