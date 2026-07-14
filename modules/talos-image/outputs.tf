output "image_id" {
  description = "Talos managed image ID"
  value       = azurerm_image.talos.id
}

output "image_name" {
  description = "Talos managed image name"
  value       = azurerm_image.talos.name
}

output "storage_account_name" {
  description = "Storage account name"
  value       = azurerm_storage_account.talos_images.name
}
