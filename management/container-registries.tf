# Container Registries
#
# Azure Container Registry for storing container images.
# Shared across all environments (dev, qa, prod).

resource "azurerm_container_registry" "main" {
  count = var.create_container_registry ? 1 : 0

  name                = var.container_registry_name
  resource_group_name = azurerm_resource_group.tfstate.name
  location            = azurerm_resource_group.tfstate.location
  sku                 = var.container_registry_sku
  admin_enabled       = var.container_registry_admin_enabled

  tags = merge(var.tags, {
    Purpose   = "container-images"
    ManagedBy = "terraform-management"
  })
}
