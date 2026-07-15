# Talos Configuration
#
# Generates machine configurations for the control plane and worker nodes and
# stores the resulting talosconfig / machine secrets in Key Vault.

module "talos_config" {
  source = "../../../modules/talos-config"

  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${var.api_server_lb_ip}:6443"

  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version

  control_plane_zones  = var.control_plane_zones # ["1", "2", "3"] for HA
  control_plane_subnet = var.subnet_control_plane_cidr
  worker_subnet        = var.subnet_workers_cidr

  pod_subnet     = var.subnet_pods_cidr
  service_subnet = var.subnet_k8s_services_cidr

  additional_api_sans = [
    "api.${var.cluster_name}.internal"
  ]
}

# Store talosconfig in Key Vault
resource "azurerm_key_vault_secret" "talosconfig" {
  name         = "talosconfig"
  value        = module.talos_config.talosconfig
  key_vault_id = data.azurerm_key_vault.talos.id

  tags = var.tags
}

# Store Talos machine secrets in Key Vault
resource "azurerm_key_vault_secret" "talos_secrets" {
  name         = "talos-secrets"
  value        = jsonencode(module.talos_config.machine_secrets)
  key_vault_id = data.azurerm_key_vault.talos.id

  tags = var.tags
}
