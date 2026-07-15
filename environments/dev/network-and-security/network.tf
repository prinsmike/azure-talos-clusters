# Network Infrastructure
#
# VNet, subnets, and NSG associations using reusable modules.

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
      # Legacy ACI subnet - kept for Azure to clean up service association link
      name = "snet-connectors-${var.environment}"
      cidr = var.subnet_connectors_cidr
      delegation = {
        name         = "aci-delegation"
        service_name = "Microsoft.ContainerInstance/containerGroups"
        actions      = ["Microsoft.Network/virtualNetworks/subnets/action"]
      }
    },
    {
      # New VM-based connectors subnet
      name = "snet-connector-vms-${var.environment}"
      cidr = var.subnet_connector_vms_cidr
    }
  ]

  tags = var.tags
}

# Control Plane NSG
module "nsg_control_plane" {
  source = "../../../modules/nsg"

  name                = "nsg-control-plane-${var.environment}-${var.location_short}"
  location            = var.location
  resource_group_name = azurerm_resource_group.network.name

  subnet_ids = {
    "snet-control-plane-${var.environment}" = module.vnet.subnet_ids["snet-control-plane-${var.environment}"]
  }

  rules = [
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
    # Talos API from management (Twingate/VPN)
    {
      name                       = "AllowTalosAPIFromManagement"
      priority                   = 147
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "50000"
      source_address_prefixes    = length(var.management_cidrs) > 0 ? var.management_cidrs : ["10.100.3.0/24"]
      destination_address_prefix = var.subnet_control_plane_cidr
    },
    # K8s API from management (Twingate/VPN)
    {
      name                       = "AllowAPIFromManagement"
      priority                   = 148
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "6443"
      source_address_prefixes    = length(var.management_cidrs) > 0 ? var.management_cidrs : ["10.100.3.0/24"]
      destination_address_prefix = var.subnet_control_plane_cidr
    },
    # Cilium health
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
    # Cilium VXLAN
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
    # ICMP for Cilium health checks from workers
    {
      name                       = "AllowICMPFromWorkers"
      priority                   = 176
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Icmp"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = var.subnet_workers_cidr
      destination_address_prefix = var.subnet_control_plane_cidr
    },
    # ICMP for Cilium health checks internal
    {
      name                       = "AllowICMPInternal"
      priority                   = 177
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Icmp"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = var.subnet_control_plane_cidr
      destination_address_prefix = var.subnet_control_plane_cidr
    },
    # Node-exporter metrics from workers (for Prometheus scraping)
    {
      name                       = "AllowNodeExporterFromWorkers"
      priority                   = 178
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "9100"
      source_address_prefix      = var.subnet_workers_cidr
      destination_address_prefix = var.subnet_control_plane_cidr
    },
    # Node-exporter metrics from pods (hostNetwork pods use node IPs)
    {
      name                       = "AllowNodeExporterFromPods"
      priority                   = 179
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "9100"
      source_address_prefix      = var.subnet_pods_cidr
      destination_address_prefix = var.subnet_control_plane_cidr
    },
    # Kubelet metrics from workers (for Prometheus scraping)
    {
      name                       = "AllowKubeletMetricsFromWorkers"
      priority                   = 180
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "10250"
      source_address_prefix      = var.subnet_workers_cidr
      destination_address_prefix = var.subnet_control_plane_cidr
    },
    # Kubelet metrics from pods (for Prometheus pod scraping)
    {
      name                       = "AllowKubeletMetricsFromPods"
      priority                   = 181
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "10250"
      source_address_prefix      = var.subnet_pods_cidr
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
  ]

  tags = var.tags
}

# Workers NSG
module "nsg_workers" {
  source = "../../../modules/nsg"

  name                = "nsg-workers-${var.environment}-${var.location_short}"
  location            = var.location
  resource_group_name = azurerm_resource_group.network.name

  subnet_ids = {
    "snet-workers-${var.environment}" = module.vnet.subnet_ids["snet-workers-${var.environment}"]
  }

  rules = [
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
    # ICMP for Cilium health checks internal
    {
      name                       = "AllowICMPInternal"
      priority                   = 181
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Icmp"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = var.subnet_workers_cidr
      destination_address_prefix = var.subnet_workers_cidr
    },
    # ICMP for Cilium health checks from CP
    {
      name                       = "AllowICMPFromCP"
      priority                   = 182
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Icmp"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = var.subnet_control_plane_cidr
      destination_address_prefix = var.subnet_workers_cidr
    },
    # Node-exporter metrics from CP (for internal monitoring)
    {
      name                       = "AllowNodeExporterFromCP"
      priority                   = 183
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "9100"
      source_address_prefix      = var.subnet_control_plane_cidr
      destination_address_prefix = var.subnet_workers_cidr
    },
    # Node-exporter metrics internal (for Prometheus scraping)
    {
      name                       = "AllowNodeExporterInternal"
      priority                   = 184
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "9100"
      source_address_prefix      = var.subnet_workers_cidr
      destination_address_prefix = var.subnet_workers_cidr
    },
    # Node-exporter metrics from pods (hostNetwork pods use node IPs)
    {
      name                       = "AllowNodeExporterFromPods"
      priority                   = 185
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "9100"
      source_address_prefix      = var.subnet_pods_cidr
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
    # HTTP/HTTPS ingress from VNet (includes Twingate connectors and internal traffic)
    {
      name                       = "AllowIngressHTTPFromVNet"
      priority                   = 200
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "80"
      source_address_prefix      = "VirtualNetwork"
      destination_address_prefix = var.subnet_workers_cidr
    },
    {
      name                       = "AllowIngressHTTPSFromVNet"
      priority                   = 201
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "VirtualNetwork"
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
  ]

  tags = var.tags
}

# Services NSG
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
      # Talos API and Trustd from VNet (for worker bootstrap)
      {
        name                       = "AllowTalosPortsFromVNet"
        priority                   = 106
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_ranges    = ["50000", "50001"]
        source_address_prefix      = var.vnet_address_space
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

# Connectors NSG (for Twingate)
module "nsg_connectors" {
  source = "../../../modules/nsg"

  name                = "nsg-connectors-${var.environment}-${var.location_short}"
  location            = var.location
  resource_group_name = azurerm_resource_group.network.name

  subnet_ids = {
    "snet-connectors-${var.environment}"    = module.vnet.subnet_ids["snet-connectors-${var.environment}"]
    "snet-connector-vms-${var.environment}" = module.vnet.subnet_ids["snet-connector-vms-${var.environment}"]
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
      source_address_prefix      = var.subnet_connector_vms_cidr
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
