# Public DNS Zones for Production Services
#
# Creates public DNS zones for external-facing services.
# All changes are peer reviewed before applying.
#
# Example usage in terraform.tfvars:
#
#   public_dns_zones = [
#     {
#       name = "apps.example.com"
#       a_records = [
#         { name = "api", records = ["203.0.113.10"] },
#         { name = "rpc", records = ["203.0.113.11"] },
#       ]
#       txt_records = [
#         { name = "@", records = ["v=spf1 -all"] },
#       ]
#     },
#     {
#       name = "apps.example.org"
#       cname_records = [
#         { name = "www", record = "cdn.example.com." },
#       ]
#     },
#   ]
#
# After applying, configure your domain registrar with the nameservers
# from the 'public_dns_zones_nameservers' output.

module "public_dns" {
  source   = "../../../modules/dns"
  for_each = { for zone in var.public_dns_zones : zone.name => zone }

  name                = each.value.name
  resource_group_name = azurerm_resource_group.network.name
  is_private          = false

  a_records     = each.value.a_records
  cname_records = each.value.cname_records
  txt_records   = each.value.txt_records
  mx_records    = each.value.mx_records

  tags = merge(var.tags, {
    Layer = "network-and-security"
  })
}
