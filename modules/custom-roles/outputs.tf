output "control_plane_role_id" {
  description = "Role definition ID for control plane nodes"
  value       = azurerm_role_definition.k8s_cloud_provider_cp.role_definition_resource_id
}

output "worker_role_id" {
  description = "Role definition ID for worker nodes"
  value       = azurerm_role_definition.k8s_cloud_provider_worker.role_definition_resource_id
}

output "control_plane_role_name" {
  description = "Role name for control plane nodes"
  value       = azurerm_role_definition.k8s_cloud_provider_cp.name
}

output "worker_role_name" {
  description = "Role name for worker nodes"
  value       = azurerm_role_definition.k8s_cloud_provider_worker.name
}
