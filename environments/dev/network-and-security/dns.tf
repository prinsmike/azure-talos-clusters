# Private DNS Zone for Internal Services
#
# This creates a private DNS zone for dev services accessible only via Twingate.
# Engineers can add DNS records by modifying the lists in terraform.tfvars or
# by passing variables via CLI.
#
# Example usage:
#   private_dns_zone_name = "int.example.com"
#   private_dns_a_records = [
#     { name = "api", records = ["10.100.1.10"] },
#     { name = "grafana", records = ["10.100.1.20"] },
#   ]

module "private_dns" {
  source = "../../../modules/dns"
  count  = var.private_dns_zone_name != "" ? 1 : 0

  name                = var.private_dns_zone_name
  resource_group_name = azurerm_resource_group.network.name
  is_private          = true

  # Link to VNet so private DNS resolves within the network
  virtual_network_links = [
    {
      name                 = "link-vnet-${var.environment}"
      virtual_network_id   = module.vnet.id
      registration_enabled = false
    }
  ]

  # A records from variable list - engineers add entries here
  a_records = var.private_dns_a_records

  # CNAME records from variable list - engineers add entries here
  cname_records = var.private_dns_cname_records

  tags = merge(var.tags, {
    Layer = "network-and-security"
  })
}
