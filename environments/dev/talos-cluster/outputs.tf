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
# VMSS
# -----------------------------------------------------------------------------

output "control_plane_vmss_id" {
  description = "Control plane VMSS ID"
  value       = module.control_plane.id
}

output "workers_vmss_id" {
  description = "Workers VMSS ID"
  value       = module.workers.id
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
