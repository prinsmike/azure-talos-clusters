output "id" {
  description = "VMSS ID"
  value       = azurerm_linux_virtual_machine_scale_set.this.id
}

output "name" {
  description = "VMSS name"
  value       = azurerm_linux_virtual_machine_scale_set.this.name
}

output "unique_id" {
  description = "VMSS unique ID"
  value       = azurerm_linux_virtual_machine_scale_set.this.unique_id
}
