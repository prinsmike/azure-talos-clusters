# -----------------------------------------------------------------------------
# Cluster Information
# -----------------------------------------------------------------------------

output "cluster_name" {
  description = "Kubernetes cluster name"
  value       = var.cluster_name
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint"
  value       = "https://${var.api_server_lb_ip}:6443"
}

output "talos_endpoint" {
  description = "Talos API endpoint"
  value       = var.api_server_lb_ip
}

# -----------------------------------------------------------------------------
# Resource Group
# -----------------------------------------------------------------------------

output "resource_group_name" {
  description = "Cluster resource group name"
  value       = azurerm_resource_group.cluster.name
}

# -----------------------------------------------------------------------------
# Load Balancer
# -----------------------------------------------------------------------------

output "api_lb_ip" {
  description = "API server load balancer IP"
  value       = var.api_server_lb_ip
}

output "api_lb_id" {
  description = "API server load balancer ID"
  value       = azurerm_lb.api_server.id
}

# -----------------------------------------------------------------------------
# VMSS - Control Plane
# -----------------------------------------------------------------------------

output "control_plane_z1_vmss_id" {
  description = "Control plane zone 1 VMSS ID"
  value       = module.control_plane_z1.id
}

output "control_plane_z2_vmss_id" {
  description = "Control plane zone 2 VMSS ID"
  value       = module.control_plane_z2.id
}

output "control_plane_z3_vmss_id" {
  description = "Control plane zone 3 VMSS ID"
  value       = module.control_plane_z3.id
}

# -----------------------------------------------------------------------------
# VMSS - Workers
# -----------------------------------------------------------------------------

output "workers_general_vmss_id" {
  description = "General workers VMSS ID"
  value       = module.workers_general.id
}

output "workers_compute_vmss_id" {
  description = "Compute workers VMSS ID"
  value       = module.workers_compute.id
}

# -----------------------------------------------------------------------------
# Capacity Information
# -----------------------------------------------------------------------------

output "general_pool_capacity" {
  description = "General worker pool capacity configuration"
  value = {
    current = var.general_pool_instance_count
    min     = var.general_pool_min_instances
    max     = var.general_pool_max_instances
  }
}

output "compute_pool_capacity" {
  description = "Compute worker pool capacity configuration"
  value = {
    current = var.compute_pool_instance_count
    min     = var.compute_pool_min_instances
    max     = var.compute_pool_max_instances
  }
}

# -----------------------------------------------------------------------------
# Talos Configuration
# -----------------------------------------------------------------------------

output "talosconfig" {
  description = "Talos client configuration"
  value       = module.talos_config.talosconfig
  sensitive   = true
}

output "cluster_dns_ip" {
  description = "Cluster DNS IP"
  value       = module.talos_config.cluster_dns_ip
}

# -----------------------------------------------------------------------------
# Shared Talos Image
# -----------------------------------------------------------------------------

output "talos_image_id" {
  description = "Shared Talos image version ID consumed by the VMSS"
  value       = data.azurerm_shared_image_version.talos.id
}

# -----------------------------------------------------------------------------
# Versions
# -----------------------------------------------------------------------------

output "talos_version" {
  description = "Talos Linux version"
  value       = var.talos_version
}

output "kubernetes_version" {
  description = "Kubernetes version"
  value       = var.kubernetes_version
}

# -----------------------------------------------------------------------------
# Next Steps
# -----------------------------------------------------------------------------

output "next_steps" {
  description = "Next steps to bootstrap the cluster"
  value       = <<-EOT
    Talos production cluster infrastructure deployed.

    Next steps:
    ===========

    1. Retrieve talosconfig from Key Vault:
       az keyvault secret show --vault-name kv-talos-${var.environment} \
         --name talosconfig --query value -o tsv > talosconfig

    2. Export TALOSCONFIG:
       export TALOSCONFIG=$(pwd)/talosconfig

    3. Wait for the control plane nodes to boot (~3-5 minutes).

    4. Bootstrap the cluster (only ONCE, on the first CP node):
       talosctl bootstrap --nodes <control-plane-z1-ip>

    5. Wait for the cluster to initialize:
       talosctl health --nodes <control-plane-z1-ip>

    6. Generate kubeconfig:
       talosctl kubeconfig --nodes <control-plane-z1-ip>

    7. Install the Cilium CNI (see kubernetes/infrastructure/).

    8. Verify the cluster:
       kubectl get nodes

    API server endpoint: https://${var.api_server_lb_ip}:6443
    Cluster name: ${var.cluster_name}
  EOT
}
