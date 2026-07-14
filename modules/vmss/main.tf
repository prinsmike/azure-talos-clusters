# Virtual Machine Scale Set Module
#
# Generic VMSS module for Talos Linux nodes.
# Supports both control plane (single-zone) and worker (multi-zone) configurations.

locals {
  placeholder_ssh_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCqal0MPYudoiFY7vPDWvfTPWZIWB/NubhB991U6uGC/OjCOy+Cu0qy5CdO1gG4dRHx0tEWKpZkLyPOlRX6D+NCU+LwfbS4nM67l7WP+3D6LBtz6oEGKI6TW13B/NpbynYKex0I/grUB/SRl90MCBmLayI7nNNWt522LpYXG8N5SnIinzcC8uScPDNZiOynbuzYqaZexdAlTpf/+pcrqtl+qVknk0Z7TBXnNPvp5OtWd4zYhD1dpAMNZrOB9YGH0i7bul/3FW2tMtUYFVtJDeYpaILxrF7gfq95M5+0F3cbyDLgcSVxYn0tBzhNtWtJYGiQCxAcg2DWcNrR9S/Ty81l talos-placeholder"
}

resource "azurerm_linux_virtual_machine_scale_set" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.vm_size
  instances           = var.instances
  admin_username      = "talos"

  disable_password_authentication = true
  single_placement_group          = var.single_placement_group
  overprovision                   = var.overprovision
  upgrade_mode                    = var.upgrade_mode
  zones                           = var.zones

  admin_ssh_key {
    username   = "talos"
    public_key = local.placeholder_ssh_key
  }

  custom_data     = base64encode(var.machine_config)
  source_image_id = var.image_id

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_type
    disk_size_gb         = var.os_disk_size_gb
  }

  network_interface {
    name                      = "nic-${var.name}"
    primary                   = true
    network_security_group_id = var.nsg_id

    ip_configuration {
      name                                   = "internal"
      primary                                = true
      subnet_id                              = var.subnet_id
      load_balancer_backend_address_pool_ids = var.load_balancer_backend_pool_ids
    }
  }

  dynamic "identity" {
    for_each = var.managed_identity_id != null ? [1] : []
    content {
      type         = "UserAssigned"
      identity_ids = [var.managed_identity_id]
    }
  }

  dynamic "boot_diagnostics" {
    for_each = var.enable_boot_diagnostics ? [1] : []
    content {
      storage_account_uri = ""
    }
  }

  lifecycle {
    ignore_changes = [
      instances,
      custom_data,
      # Azure CCM dynamically adds load balancer backend pools for LoadBalancer services
      # We must ignore these changes to prevent Terraform from reverting CCM's work
      network_interface[0].ip_configuration[0].load_balancer_backend_address_pool_ids,
    ]
  }

  tags = var.tags
}
