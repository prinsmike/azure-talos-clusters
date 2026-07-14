output "id" {
  description = "Key Vault ID"
  value       = azurerm_key_vault.this.id
}

output "name" {
  description = "Key Vault name"
  value       = azurerm_key_vault.this.name
}

output "uri" {
  description = "Key Vault URI"
  value       = azurerm_key_vault.this.vault_uri
}

output "tenant_id" {
  description = "Key Vault tenant ID"
  value       = azurerm_key_vault.this.tenant_id
}
