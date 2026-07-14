# Twingate Connector VM Module
#
# Deploys Twingate connectors using Azure Virtual Machines.
# Creates the Twingate remote network and connector resources,
# then deploys VMs with Docker and the connector container.

# -----------------------------------------------------------------------------
# Twingate Resources
# -----------------------------------------------------------------------------

resource "twingate_remote_network" "this" {
  name = var.twingate_network_name
}

resource "twingate_connector" "this" {
  count = var.connector_count

  remote_network_id = twingate_remote_network.this.id
  name              = "${var.name}-connector-${count.index + 1}"
}

resource "twingate_connector_tokens" "this" {
  count = var.connector_count

  connector_id = twingate_connector.this[count.index].id
}

# -----------------------------------------------------------------------------
# Twingate Resources (Network Access)
# -----------------------------------------------------------------------------

resource "twingate_resource" "this" {
  for_each = { for r in var.twingate_resources : r.name => r }

  name              = each.value.name
  address           = each.value.address
  remote_network_id = twingate_remote_network.this.id

  dynamic "access_group" {
    for_each = var.twingate_group_ids
    content {
      group_id = access_group.value
    }
  }
}

# -----------------------------------------------------------------------------
# Network Interfaces
# -----------------------------------------------------------------------------

resource "azurerm_network_interface" "connector" {
  count = var.connector_count

  name                = "${var.name}-connector-${count.index + 1}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Virtual Machines
# -----------------------------------------------------------------------------

resource "azurerm_linux_virtual_machine" "connector" {
  count = var.connector_count

  name                = "${var.name}-connector-${count.index + 1}"
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = var.vm_size
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.connector[count.index].id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    name                 = "${var.name}-connector-${count.index + 1}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_type
    disk_size_gb         = var.os_disk_size_gb
  }

  source_image_reference {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.image_sku
    version   = var.image_version
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init.tpl", {
    twingate_network    = var.twingate_account
    access_token        = twingate_connector_tokens.this[count.index].access_token
    refresh_token       = twingate_connector_tokens.this[count.index].refresh_token
    connector_image     = var.connector_image
    enable_auto_updates = var.enable_auto_updates
  }))

  # Prevent recreation when cloud-init changes (tokens rotate)
  lifecycle {
    ignore_changes = [custom_data]
  }

  tags = var.tags
}
