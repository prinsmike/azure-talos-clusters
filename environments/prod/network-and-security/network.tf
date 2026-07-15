# Network Infrastructure
#
# VNet, subnets, and NSG associations using reusable modules.
# Production configuration with full HA NSG rules.

locals {
  resource_prefix = "${var.project}-${var.environment}"
}

# Resource Group for the network-and-security layer
resource "azurerm_resource_group" "network" {
  name     = "rg-${local.resource_prefix}-network-${var.location_short}"
  location = var.location

  tags = merge(var.tags, {
    Layer = "network-and-security"
  })
}

# Virtual Network
module "vnet" {
  source = "../../../modules/vnet"

  name                = "vnet-${local.resource_prefix}-${var.location_short}"
  location            = var.location
  resource_group_name = azurerm_resource_group.network.name
  address_space       = [var.vnet_address_space]

  subnets = [
    {
      name = "snet-control-plane-${var.environment}"
      cidr = var.subnet_control_plane_cidr
    },
    {
      name = "snet-workers-${var.environment}"
      cidr = var.subnet_workers_cidr
    },
    {
      name = "snet-services-${var.environment}"
      cidr = var.subnet_services_cidr
    },
    {
      name = "snet-pods-${var.environment}"
      cidr = var.subnet_pods_cidr
      delegation = {
        name         = "pod-delegation"
        service_name = "Microsoft.ContainerInstance/containerGroups"
        actions      = ["Microsoft.Network/virtualNetworks/subnets/action"]
      }
    },
    {
      name = "snet-k8s-services-${var.environment}"
      cidr = var.subnet_k8s_services_cidr
    },
    {
      name = "snet-connectors-${var.environment}"
      cidr = var.subnet_connectors_cidr
    }
  ]

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Control Plane NSG
# Production rules include management access and node-exporter
# -----------------------------------------------------------------------------

module "nsg_control_plane" {
  source = "../../../modules/nsg"

  name                = "nsg-control-plane-${var.environment}-${var.location_short}"
  location            = var.location
  resource_group_name = azurerm_resource_group.network.name

  subnet_ids = {
    "snet-control-plane-${var.environment}" = module.vnet.subnet_ids["snet-control-plane-${var.environment}"]
  }

  rules = concat(
    [
      # K8s API from workers
      {
        name                       = "AllowAPIFromWorkers"
        priority                   = 100
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "6443"
        source_address_prefix      = var.subnet_workers_cidr
        destination_address_prefix = var.subnet_control_plane_cidr
      },
      # Azure LB health probes
      {
        name                       = "AllowAzureLBHealthProbes"
        priority                   = 105
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "6443"
        source_address_prefix      = "AzureLoadBalancer"
        destination_address_prefix = var.subnet_control_plane_cidr
      },
      # Talos API from workers
      {
        name                       = "AllowTalosAPIFromWorkers"
        priority                   = 120
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "50000"
        source_address_prefix      = var.subnet_workers_cidr
        destination_address_prefix = var.subnet_control_plane_cidr
      },
      # Trustd for certificate signing
      {
        name                       = "AllowTrustdFromWorkers"
        priority                   = 125
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "50001"
        source_address_prefix      = var.subnet_workers_cidr
        destination_address_prefix = var.subnet_control_plane_cidr
      },
      # etcd peer communication
      {
        name                       = "AllowEtcdPeer"
        priority                   = 140
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_ranges    = ["2379", "2380"]
        source_address_prefix      = var.subnet_control_plane_cidr
        destination_address_prefix = var.subnet_control_plane_cidr
      },
      # Talos API internal
      {
        name                       = "AllowTalosAPIInternal"
        priority                   = 145
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "50000"
        source_address_prefix      = var.subnet_control_plane_cidr
        destination_address_prefix = var.subnet_control_plane_cidr
      },
      # Node-exporter from pods (Prometheus)
      {
        name                       = "AllowNodeExporterFromPods"
        priority                   = 150
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "9100"
        source_address_prefix      = var.subnet_pods_cidr
        destination_address_prefix = var.subnet_control_plane_cidr
      },
      # Node-exporter from workers (SNAT'd traffic)
      {
        name                       = "AllowNodeExporterFromWorkers"
        priority                   = 155
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "9100"
        source_address_prefix      = var.subnet_workers_cidr
        destination_address_prefix = var.subnet_control_plane_cidr
      },
      # Cilium health from workers
      {
        name                       = "AllowCiliumHealthFromWorkers"
        priority                   = 160
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "4240"
        source_address_prefix      = var.subnet_workers_cidr
        destination_address_prefix = var.subnet_control_plane_cidr
      },
      # Cilium VXLAN from workers
      {
        name                       = "AllowCiliumVXLANFromWorkers"
        priority                   = 165
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Udp"
        source_port_range          = "*"
        destination_port_range     = "8472"
        source_address_prefix      = var.subnet_workers_cidr
        destination_address_prefix = var.subnet_control_plane_cidr
      },
      # Cilium health internal
      {
        name                       = "AllowCiliumHealthInternal"
        priority                   = 170
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "4240"
        source_address_prefix      = var.subnet_control_plane_cidr
        destination_address_prefix = var.subnet_control_plane_cidr
      },
      # Cilium VXLAN internal
      {
        name                       = "AllowCiliumVXLANInternal"
        priority                   = 175
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Udp"
        source_port_range          = "*"
        destination_port_range     = "8472"
        source_address_prefix      = var.subnet_control_plane_cidr
        destination_address_prefix = var.subnet_control_plane_cidr
      },
      # Allow all outbound
      {
        name                       = "AllowAllOutbound"
        priority                   = 100
        direction                  = "Outbound"
        access                     = "Allow"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefix      = var.subnet_control_plane_cidr
        destination_address_prefix = "*"
      },
      # Deny all inbound
      {
        name                       = "DenyAllInbound"
        priority                   = 4096
        direction                  = "Inbound"
        access                     = "Deny"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
      }
    ],
    # Conditional management CIDR rules
    length(var.management_cidrs) > 0 ? [
      {
        name                       = "AllowAPIFromManagement"
        priority                   = 110
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "6443"
        source_address_prefixes    = var.management_cidrs
        destination_address_prefix = var.subnet_control_plane_cidr
      },
      {
        name                       = "AllowTalosAPIFromManagement"
        priority                   = 130
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "50000"
        source_address_prefixes    = var.management_cidrs
        destination_address_prefix = var.subnet_control_plane_cidr
      }
    ] : []
  )

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Workers NSG
# Production rules include node-exporter, WireGuard, and any custom ingress rules
# supplied via var.custom_worker_ingress_rules.
# -----------------------------------------------------------------------------

module "nsg_workers" {
  source = "../../../modules/nsg"

  name                = "nsg-workers-${var.environment}-${var.location_short}"
  location            = var.location
  resource_group_name = azurerm_resource_group.network.name

  subnet_ids = {
    "snet-workers-${var.environment}" = module.vnet.subnet_ids["snet-workers-${var.environment}"]
  }

  rules = concat(
    [
      # Kubelet from control plane
      {
        name                       = "AllowKubeletFromCP"
        priority                   = 100
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "10250"
        source_address_prefix      = var.subnet_control_plane_cidr
        destination_address_prefix = var.subnet_workers_cidr
      },
      # Talos API from control plane
      {
        name                       = "AllowTalosAPIFromCP"
        priority                   = 110
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "50000"
        source_address_prefix      = var.subnet_control_plane_cidr
        destination_address_prefix = var.subnet_workers_cidr
      },
      # Cilium health internal
      {
        name                       = "AllowCiliumHealth"
        priority                   = 130
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "4240"
        source_address_prefix      = var.subnet_workers_cidr
        destination_address_prefix = var.subnet_workers_cidr
      },
      # Cilium VXLAN internal
      {
        name                       = "AllowCiliumVXLAN"
        priority                   = 140
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Udp"
        source_port_range          = "*"
        destination_port_range     = "8472"
        source_address_prefix      = var.subnet_workers_cidr
        destination_address_prefix = var.subnet_workers_cidr
      },
      # WireGuard for Cilium encryption
      {
        name                       = "AllowWireGuard"
        priority                   = 150
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Udp"
        source_port_range          = "*"
        destination_port_range     = "51871"
        source_address_prefix      = var.subnet_workers_cidr
        destination_address_prefix = var.subnet_workers_cidr
      },
      # Node-exporter from pods (Prometheus)
      {
        name                       = "AllowNodeExporterFromPods"
        priority                   = 160
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "9100"
        source_address_prefix      = var.subnet_pods_cidr
        destination_address_prefix = var.subnet_workers_cidr
      },
      # Node-exporter internal (SNAT'd traffic)
      {
        name                       = "AllowNodeExporterInternal"
        priority                   = 165
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "9100"
        source_address_prefix      = var.subnet_workers_cidr
        destination_address_prefix = var.subnet_workers_cidr
      },
      # Cilium health from CP
      {
        name                       = "AllowCiliumHealthFromCP"
        priority                   = 170
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "4240"
        source_address_prefix      = var.subnet_control_plane_cidr
        destination_address_prefix = var.subnet_workers_cidr
      },
      # Cilium VXLAN from CP
      {
        name                       = "AllowCiliumVXLANFromCP"
        priority                   = 180
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Udp"
        source_port_range          = "*"
        destination_port_range     = "8472"
        source_address_prefix      = var.subnet_control_plane_cidr
        destination_address_prefix = var.subnet_workers_cidr
      },
      # NodePort from services subnet
      {
        name                       = "AllowNodePortFromServices"
        priority                   = 190
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "30000-32767"
        source_address_prefix      = var.subnet_services_cidr
        destination_address_prefix = var.subnet_workers_cidr
      },
      # Azure LB health probes
      {
        name                       = "AllowAzureLBHealthProbes"
        priority                   = 195
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "30000-32767"
        source_address_prefix      = "AzureLoadBalancer"
        destination_address_prefix = var.subnet_workers_cidr
      },
      # Allow all outbound
      {
        name                       = "AllowAllOutbound"
        priority                   = 100
        direction                  = "Outbound"
        access                     = "Allow"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefix      = var.subnet_workers_cidr
        destination_address_prefix = "*"
      },
      # Deny all inbound
      {
        name                       = "DenyAllInbound"
        priority                   = 4096
        direction                  = "Inbound"
        access                     = "Deny"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
      }
    ],
    # Conditional management CIDR rules
    length(var.management_cidrs) > 0 ? [
      {
        name                       = "AllowTalosAPIFromManagement"
        priority                   = 120
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "50000"
        source_address_prefixes    = var.management_cidrs
        destination_address_prefix = var.subnet_workers_cidr
      }
    ] : [],
    # Custom worker ingress rules — declaratively open extra ports for any
    # workload (e.g. a peer-to-peer protocol). Each entry is a full NSG rule.
    var.custom_worker_ingress_rules
  )

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Services NSG
# Security: API server access restricted to VNet + management CIDRs only
# -----------------------------------------------------------------------------

module "nsg_services" {
  source = "../../../modules/nsg"

  name                = "nsg-services-${var.environment}-${var.location_short}"
  location            = var.location
  resource_group_name = azurerm_resource_group.network.name

  subnet_ids = {
    "snet-services-${var.environment}" = module.vnet.subnet_ids["snet-services-${var.environment}"]
  }

  rules = concat(
    [
      # API server LB - internal cluster access only
      {
        name                       = "AllowAPIServerFromVNet"
        priority                   = 100
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "6443"
        source_address_prefix      = var.vnet_address_space
        destination_address_prefix = var.subnet_services_cidr
      },
      # Azure LB health probes for API server
      {
        name                       = "AllowAPIServerLBHealthProbes"
        priority                   = 105
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "6443"
        source_address_prefix      = "AzureLoadBalancer"
        destination_address_prefix = var.subnet_services_cidr
      },
      # HTTPS
      {
        name                       = "AllowHTTPS"
        priority                   = 110
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "443"
        source_address_prefix      = "*"
        destination_address_prefix = var.subnet_services_cidr
      },
      # HTTP
      {
        name                       = "AllowHTTP"
        priority                   = 115
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "80"
        source_address_prefix      = "*"
        destination_address_prefix = var.subnet_services_cidr
      },
      # Azure LB health probes (general)
      {
        name                       = "AllowAzureLBHealthProbes"
        priority                   = 120
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefix      = "AzureLoadBalancer"
        destination_address_prefix = var.subnet_services_cidr
      },
      # Allow all outbound
      {
        name                       = "AllowAllOutbound"
        priority                   = 100
        direction                  = "Outbound"
        access                     = "Allow"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefix      = var.subnet_services_cidr
        destination_address_prefix = "*"
      },
      # Deny all inbound
      {
        name                       = "DenyAllInbound"
        priority                   = 4096
        direction                  = "Inbound"
        access                     = "Deny"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
      }
    ],
    # Conditional management CIDR access to API server
    length(var.management_cidrs) > 0 ? [
      {
        name                       = "AllowAPIServerFromManagement"
        priority                   = 101
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "6443"
        source_address_prefixes    = var.management_cidrs
        destination_address_prefix = var.subnet_services_cidr
      }
    ] : []
  )

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Connectors NSG (for Twingate)
# -----------------------------------------------------------------------------

module "nsg_connectors" {
  source = "../../../modules/nsg"

  name                = "nsg-connectors-${var.environment}-${var.location_short}"
  location            = var.location
  resource_group_name = azurerm_resource_group.network.name

  subnet_ids = {
    "snet-connectors-${var.environment}" = module.vnet.subnet_ids["snet-connectors-${var.environment}"]
  }

  rules = [
    # Allow all outbound (Twingate uses outbound connections only)
    {
      name                       = "AllowAllOutbound"
      priority                   = 100
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = var.subnet_connectors_cidr
      destination_address_prefix = "*"
    },
    # Deny all inbound (connectors don't need inbound)
    {
      name                       = "DenyAllInbound"
      priority                   = 4096
      direction                  = "Inbound"
      access                     = "Deny"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
  ]

  tags = var.tags
}
