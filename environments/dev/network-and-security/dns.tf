# DNS — three-zone model (see docs/adr/0008-dns-delegated-self-service.md)
#
#   1. public_dns         Azure Public DNS  — internet-facing records. Security-owned;
#                         changed only via peer-reviewed PR to this (security-owned) layer.
#   2. internal_apex_dns  Azure Private DNS "int.example.com" — internal apex plus
#                         top-level/infra records (api, vault, grafana, ingress...).
#                         Security-owned; records set via the variables below.
#   3. internal_apps_dns  Azure Private DNS "apps.int.example.com" — developer app
#                         subdomains (myapp.apps.int.example.com), created automatically
#                         by external-dns in-cluster from Ingress/HTTPRoute annotations.
#                         NO Terraform-managed records here.
#
# Azure Private DNS uses longest-suffix matching (NOT NS delegation) between the two
# private zones, so myapp.apps.int.example.com resolves against the apps zone while
# api.int.example.com resolves against the apex zone. That split is what lets the
# external-dns identity hold DNS Zone Contributor on the apps zone ONLY (see iam.tf).

# -----------------------------------------------------------------------------
# Public zones (security-owned; peer-reviewed)
# -----------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------
# Internal apex private zone (security-owned records)
# -----------------------------------------------------------------------------
module "internal_apex_dns" {
  source = "../../../modules/dns"
  count  = var.internal_apex_zone_name != "" ? 1 : 0

  name                = var.internal_apex_zone_name
  resource_group_name = azurerm_resource_group.network.name
  is_private          = true

  virtual_network_links = [
    {
      name                 = "link-apex-${var.environment}"
      virtual_network_id   = module.vnet.id
      registration_enabled = false
    }
  ]

  # Top-level/infra records — security adds entries here (peer-reviewed).
  a_records     = var.internal_apex_a_records
  cname_records = var.internal_apex_cname_records

  tags = merge(var.tags, {
    Layer = "network-and-security"
  })
}

# -----------------------------------------------------------------------------
# Internal apps private zone (developer self-service via external-dns)
# -----------------------------------------------------------------------------
# Records in this zone are created in-cluster by external-dns, whose identity is
# scoped to THIS zone only (see iam.tf). Terraform intentionally manages no records
# here — do not add a_records/cname_records to this module.
module "internal_apps_dns" {
  source = "../../../modules/dns"
  count  = var.internal_apps_zone_name != "" ? 1 : 0

  name                = var.internal_apps_zone_name
  resource_group_name = azurerm_resource_group.network.name
  is_private          = true

  virtual_network_links = [
    {
      name                 = "link-apps-${var.environment}"
      virtual_network_id   = module.vnet.id
      registration_enabled = false
    }
  ]

  tags = merge(var.tags, {
    Layer          = "network-and-security"
    ManagedRecords = "external-dns"
  })
}
