output "control_plane_configs" {
  description = "Control plane machine configurations by zone"
  value       = { for k, v in data.talos_machine_configuration.control_plane : k => v.machine_configuration }
  sensitive   = true
}

output "worker_config" {
  description = "Worker machine configuration"
  value       = data.talos_machine_configuration.worker.machine_configuration
  sensitive   = true
}

output "talosconfig" {
  description = "Talos client configuration"
  value       = data.talos_client_configuration.cluster.talos_config
  sensitive   = true
}

output "cluster_dns_ip" {
  description = "Cluster DNS IP"
  value       = local.cluster_dns_ip
}

output "machine_secrets" {
  description = "Talos machine secrets for bootstrapping"
  value       = talos_machine_secrets.cluster.machine_secrets
  sensitive   = true
}

output "secrets_backup_command" {
  description = "Command to backup Talos secrets to Key Vault (run once after initial apply)"
  value       = <<-EOT
    # IMPORTANT: Run this after initial cluster creation to backup secrets to Key Vault
    # This enables disaster recovery without Terraform state access

    terraform output -raw machine_secrets | az keyvault secret set \
      --vault-name ${var.operations_key_vault_name} \
      --name "talos-secrets-${var.environment}" \
      --value @-

    # Verify backup:
    az keyvault secret show --vault-name ${var.operations_key_vault_name} --name "talos-secrets-${var.environment}" --query "id"
  EOT
}
