# Talos Configuration Module
#
# Generates Talos machine configurations for control plane and worker nodes.

terraform {
  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.5"
    }
  }
}

locals {
  # Extract host from endpoint (remove protocol and port)
  endpoint_without_protocol = split("://", var.cluster_endpoint)[1]
  endpoint_host             = split(":", local.endpoint_without_protocol)[0]

  # Calculate cluster DNS IP (10th IP in service subnet)
  service_subnet_parts = split(".", split("/", var.service_subnet)[0])
  cluster_dns_ip       = "${local.service_subnet_parts[0]}.${local.service_subnet_parts[1]}.${local.service_subnet_parts[2]}.10"

  # Combine SANs
  all_api_sans = concat([local.endpoint_host], var.additional_api_sans)
}

resource "talos_machine_secrets" "cluster" {
  talos_version = var.talos_version

  # SECURITY: Prevent accidental secret regeneration which would break the cluster
  # Tainting this resource would generate new PKI material incompatible with existing nodes
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      talos_version # Allow version updates without regenerating secrets
    ]
  }
}

# Control Plane Machine Configurations (one per zone)
data "talos_machine_configuration" "control_plane" {
  for_each = toset(var.control_plane_zones)

  cluster_name       = var.cluster_name
  cluster_endpoint   = var.cluster_endpoint
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.cluster.machine_secrets
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version

  docs     = false
  examples = false

  config_patches = [
    yamlencode({
      machine = {
        network = {
          hostname = "${var.cluster_name}-cp-zone${each.value}"
          interfaces = [{
            interface = "eth0"
            dhcp      = true
          }]
        }
        kubelet = {
          clusterDNS = [local.cluster_dns_ip]
          nodeIP = {
            validSubnets = [var.control_plane_subnet]
          }
          extraArgs = {
            cloud-provider = "external"
          }
        }
        install = {
          disk  = var.install_disk
          image = "ghcr.io/siderolabs/installer:${var.talos_version}"
        }
        certSANs = local.all_api_sans
        sysctls = {
          "net.core.somaxconn"           = "65535"
          "net.ipv4.tcp_max_syn_backlog" = "8096"
        }
      }
      cluster = {
        network = {
          cni            = { name = "none" }
          dnsDomain      = var.dns_domain
          podSubnets     = [var.pod_subnet]
          serviceSubnets = [var.service_subnet]
        }
        proxy = { disabled = true }
        apiServer = {
          certSANs  = local.all_api_sans
          extraArgs = { "cloud-provider" = "external" }
        }
        controllerManager = {
          extraArgs = {
            "cloud-provider"              = "external"
            "bind-address"                = "0.0.0.0"
            "terminated-pod-gc-threshold" = "100"
          }
        }
        scheduler = { extraArgs = { "bind-address" = "0.0.0.0" } }
        etcd = {
          advertisedSubnets = [var.control_plane_subnet]
          extraArgs = {
            "quota-backend-bytes"       = "8589934592"
            "auto-compaction-retention" = "5"
          }
        }
        discovery = {
          enabled = true
          registries = {
            kubernetes = { disabled = false }
            service    = { disabled = false }
          }
        }
      }
    })
  ]
}

# Worker Machine Configuration
data "talos_machine_configuration" "worker" {
  cluster_name       = var.cluster_name
  cluster_endpoint   = var.cluster_endpoint
  machine_type       = "worker"
  machine_secrets    = talos_machine_secrets.cluster.machine_secrets
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version

  docs     = false
  examples = false

  config_patches = [
    yamlencode({
      machine = {
        # Include expected worker IPs in certificate SANs to fix DHCP timing issue
        # where CSR is generated before IP assignment
        certSANs = var.worker_cert_sans
        kubelet = {
          clusterDNS = [local.cluster_dns_ip]
          nodeIP = {
            validSubnets = [var.worker_subnet]
          }
          extraArgs = {
            cloud-provider          = "external"
            max-pods                = "110"
            image-gc-high-threshold = "85"
            image-gc-low-threshold  = "80"
          }
        }
        network = {
          interfaces = [
            {
              interface = "eth0"
              dhcp      = true
            }
          ]
        }
        time = {
          servers     = ["time.cloudflare.com"]
          bootTimeout = "5m"
        }
        install = {
          disk  = var.install_disk
          image = "ghcr.io/siderolabs/installer:${var.talos_version}"
        }
        sysctls = {
          "net.core.somaxconn"           = "65535"
          "net.ipv4.tcp_max_syn_backlog" = "8096"
          "vm.max_map_count"             = "262144"
        }
      }
      cluster = {
        network = {
          cni            = { name = "none" }
          podSubnets     = [var.pod_subnet]
          serviceSubnets = [var.service_subnet]
        }
        discovery = {
          enabled    = true
          registries = { kubernetes = { disabled = false } }
        }
      }
    })
  ]
}

# Client configuration for talosctl
data "talos_client_configuration" "cluster" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.cluster.client_configuration
  endpoints            = [local.endpoint_host]
}
