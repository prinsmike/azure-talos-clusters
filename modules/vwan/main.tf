# vWAN Module
#
# Creates Azure Virtual WAN with a Secured Hub (Azure Firewall).
# Used for centralized network connectivity and security.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# Virtual WAN
resource "azurerm_virtual_wan" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name

  type                              = "Standard"
  disable_vpn_encryption            = false
  allow_branch_to_branch_traffic    = true
  office365_local_breakout_category = "None"

  tags = var.tags
}

# Virtual Hub
resource "azurerm_virtual_hub" "this" {
  name                = "${var.name}-hub"
  location            = var.location
  resource_group_name = var.resource_group_name
  virtual_wan_id      = azurerm_virtual_wan.this.id
  address_prefix      = var.hub_address_prefix
  sku                 = "Standard"

  tags = var.tags
}

# Firewall Policy
resource "azurerm_firewall_policy" "this" {
  name                = "${var.name}-fw-policy"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.firewall_sku

  dns {
    proxy_enabled = true
  }

  tags = var.tags
}

# Firewall Policy Rule Collection Group - Network Rules
resource "azurerm_firewall_policy_rule_collection_group" "network" {
  name               = "network-rules"
  firewall_policy_id = azurerm_firewall_policy.this.id
  priority           = 100

  network_rule_collection {
    name     = "allow-outbound"
    priority = 100
    action   = "Allow"

    rule {
      name                  = "allow-https"
      protocols             = ["TCP"]
      source_addresses      = ["*"]
      destination_addresses = ["*"]
      destination_ports     = ["443"]
    }

    rule {
      name                  = "allow-http"
      protocols             = ["TCP"]
      source_addresses      = ["*"]
      destination_addresses = ["*"]
      destination_ports     = ["80"]
    }

    rule {
      name                  = "allow-dns-udp"
      protocols             = ["UDP"]
      source_addresses      = ["*"]
      destination_addresses = ["*"]
      destination_ports     = ["53"]
    }

    rule {
      name                  = "allow-dns-tcp"
      protocols             = ["TCP"]
      source_addresses      = ["*"]
      destination_addresses = ["*"]
      destination_ports     = ["53"]
    }

    rule {
      name                  = "allow-ntp"
      protocols             = ["UDP"]
      source_addresses      = ["*"]
      destination_addresses = ["*"]
      destination_ports     = ["123"]
    }
  }

  # Allow spoke-to-spoke traffic within vWAN
  network_rule_collection {
    name     = "allow-spoke-to-spoke"
    priority = 200
    action   = "Allow"

    rule {
      name                  = "allow-rfc1918"
      protocols             = ["Any"]
      source_addresses      = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
      destination_addresses = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
      destination_ports     = ["*"]
    }
  }
}

# Firewall Policy Rule Collection Group - Application Rules
resource "azurerm_firewall_policy_rule_collection_group" "application" {
  name               = "application-rules"
  firewall_policy_id = azurerm_firewall_policy.this.id
  priority           = 200

  application_rule_collection {
    name     = "allow-azure-services"
    priority = 100
    action   = "Allow"

    rule {
      name = "azure-services"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = ["*"]
      destination_fqdns = ["*.azure.com", "*.microsoft.com", "*.windows.net", "*.azurecr.io"]
    }

    rule {
      name = "package-managers"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = ["*"]
      destination_fqdns = ["*.ubuntu.com", "*.debian.org", "*.docker.io", "*.docker.com", "registry-1.docker.io", "production.cloudflare.docker.com"]
    }

    rule {
      name = "kubernetes"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = ["*"]
      destination_fqdns = ["*.kubernetes.io", "*.k8s.io", "ghcr.io", "*.github.com", "github.com"]
    }
  }
}

# Azure Firewall in Virtual Hub (Secured Hub)
resource "azurerm_firewall" "this" {
  name                = "${var.name}-fw"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "AZFW_Hub"
  sku_tier            = var.firewall_sku
  firewall_policy_id  = azurerm_firewall_policy.this.id

  virtual_hub {
    virtual_hub_id  = azurerm_virtual_hub.this.id
    public_ip_count = 1
  }

  tags = var.tags
}

# Firewall Policy Rule Collection Group - DNAT Rules (Inbound)
# Placed after firewall to reference its public IP
resource "azurerm_firewall_policy_rule_collection_group" "dnat" {
  count              = length(var.dnat_rules) > 0 ? 1 : 0
  name               = "dnat-rules"
  firewall_policy_id = azurerm_firewall_policy.this.id
  priority           = 110

  nat_rule_collection {
    name     = "inbound-dnat"
    priority = 100
    action   = "Dnat"

    dynamic "rule" {
      for_each = var.dnat_rules
      content {
        name                = rule.value.name
        protocols           = rule.value.protocols
        source_addresses    = rule.value.source_addresses
        destination_address = azurerm_firewall.this.virtual_hub[0].public_ip_addresses[0]
        destination_ports   = rule.value.destination_ports
        translated_address  = rule.value.translated_address
        translated_port     = rule.value.translated_port
      }
    }
  }
}
