output "gallery_id" {
  description = "Azure Compute Gallery ID"
  value       = azurerm_shared_image_gallery.talos.id
}

output "gallery_name" {
  description = "Azure Compute Gallery name"
  value       = azurerm_shared_image_gallery.talos.name
}

output "image_definition_id" {
  description = "Shared image definition ID"
  value       = azurerm_shared_image.talos.id
}

output "image_definition_name" {
  description = "Shared image definition name"
  value       = azurerm_shared_image.talos.name
}

output "image_version_id" {
  description = "Shared image version ID — this is what VMSS consumes as source_image_id"
  value       = azurerm_shared_image_version.talos.id
}

output "talos_version" {
  description = "Talos Linux version published to the gallery"
  value       = var.talos_version
}

output "managed_image_id" {
  description = "Source managed image ID (the gallery version is built from this)"
  value       = azurerm_image.talos.id
}

output "storage_account_name" {
  description = "Storage account holding the uploaded VHD"
  value       = azurerm_storage_account.talos_images.name
}
