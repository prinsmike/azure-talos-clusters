# DNS Module - Supports both private and public DNS zones
#
# Private zones: Used for internal services, linked to VNets
# Public zones: Used for external services, returns nameservers for delegation

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
  }
}

#------------------------------------------------------------------------------
# Private DNS Zone (for internal/dev environments)
#------------------------------------------------------------------------------

resource "azurerm_private_dns_zone" "this" {
  count = var.is_private ? 1 : 0

  name                = var.name
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  for_each = var.is_private ? { for link in var.virtual_network_links : link.name => link } : {}

  name                 = each.value.name
  private_dns_zone_id  = azurerm_private_dns_zone.this[0].id
  virtual_network_id   = each.value.virtual_network_id
  registration_enabled = each.value.registration_enabled
  tags                 = var.tags
}

#------------------------------------------------------------------------------
# Public DNS Zone (for production/external services)
#------------------------------------------------------------------------------

resource "azurerm_dns_zone" "this" {
  count = var.is_private ? 0 : 1

  name                = var.name
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

#------------------------------------------------------------------------------
# A Records - Private Zone
#------------------------------------------------------------------------------

resource "azurerm_private_dns_a_record" "this" {
  for_each = var.is_private ? { for record in var.a_records : record.name => record } : {}

  name                = each.value.name
  private_dns_zone_id = azurerm_private_dns_zone.this[0].id
  ttl                 = each.value.ttl
  records             = each.value.records
  tags                = var.tags
}

#------------------------------------------------------------------------------
# A Records - Public Zone
#------------------------------------------------------------------------------

resource "azurerm_dns_a_record" "this" {
  for_each = var.is_private ? {} : { for record in var.a_records : record.name => record }

  name                = each.value.name
  zone_name           = azurerm_dns_zone.this[0].name
  resource_group_name = var.resource_group_name
  ttl                 = each.value.ttl
  records             = each.value.records
  tags                = var.tags
}

#------------------------------------------------------------------------------
# CNAME Records - Private Zone
#------------------------------------------------------------------------------

resource "azurerm_private_dns_cname_record" "this" {
  for_each = var.is_private ? { for record in var.cname_records : record.name => record } : {}

  name                = each.value.name
  private_dns_zone_id = azurerm_private_dns_zone.this[0].id
  ttl                 = each.value.ttl
  record              = each.value.record
  tags                = var.tags
}

#------------------------------------------------------------------------------
# CNAME Records - Public Zone
#------------------------------------------------------------------------------

resource "azurerm_dns_cname_record" "this" {
  for_each = var.is_private ? {} : { for record in var.cname_records : record.name => record }

  name                = each.value.name
  zone_name           = azurerm_dns_zone.this[0].name
  resource_group_name = var.resource_group_name
  ttl                 = each.value.ttl
  record              = each.value.record
  tags                = var.tags
}

#------------------------------------------------------------------------------
# TXT Records - Private Zone
#------------------------------------------------------------------------------

resource "azurerm_private_dns_txt_record" "this" {
  for_each = var.is_private ? { for record in var.txt_records : record.name => record } : {}

  name                = each.value.name
  private_dns_zone_id = azurerm_private_dns_zone.this[0].id
  ttl                 = each.value.ttl

  dynamic "record" {
    for_each = each.value.records
    content {
      value = record.value
    }
  }

  tags = var.tags
}

#------------------------------------------------------------------------------
# TXT Records - Public Zone
#------------------------------------------------------------------------------

resource "azurerm_dns_txt_record" "this" {
  for_each = var.is_private ? {} : { for record in var.txt_records : record.name => record }

  name                = each.value.name
  zone_name           = azurerm_dns_zone.this[0].name
  resource_group_name = var.resource_group_name
  ttl                 = each.value.ttl

  dynamic "record" {
    for_each = each.value.records
    content {
      value = record.value
    }
  }

  tags = var.tags
}

#------------------------------------------------------------------------------
# MX Records - Public Zone Only
#------------------------------------------------------------------------------

resource "azurerm_dns_mx_record" "this" {
  for_each = var.is_private ? {} : { for record in var.mx_records : record.name => record }

  name                = each.value.name
  zone_name           = azurerm_dns_zone.this[0].name
  resource_group_name = var.resource_group_name
  ttl                 = each.value.ttl

  dynamic "record" {
    for_each = each.value.records
    content {
      preference = record.value.preference
      exchange   = record.value.exchange
    }
  }

  tags = var.tags
}

#------------------------------------------------------------------------------
# SRV Records - Private Zone
#------------------------------------------------------------------------------

resource "azurerm_private_dns_srv_record" "this" {
  for_each = var.is_private ? { for record in var.srv_records : record.name => record } : {}

  name                = each.value.name
  private_dns_zone_id = azurerm_private_dns_zone.this[0].id
  ttl                 = each.value.ttl

  dynamic "record" {
    for_each = each.value.records
    content {
      priority = record.value.priority
      weight   = record.value.weight
      port     = record.value.port
      target   = record.value.target
    }
  }

  tags = var.tags
}

#------------------------------------------------------------------------------
# SRV Records - Public Zone
#------------------------------------------------------------------------------

resource "azurerm_dns_srv_record" "this" {
  for_each = var.is_private ? {} : { for record in var.srv_records : record.name => record }

  name                = each.value.name
  zone_name           = azurerm_dns_zone.this[0].name
  resource_group_name = var.resource_group_name
  ttl                 = each.value.ttl

  dynamic "record" {
    for_each = each.value.records
    content {
      priority = record.value.priority
      weight   = record.value.weight
      port     = record.value.port
      target   = record.value.target
    }
  }

  tags = var.tags
}
