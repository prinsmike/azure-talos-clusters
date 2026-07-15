# Key Vault
#
# Stores Talos secrets (talosconfig, kubeconfig, machine configs).

module "key_vault" {
  source = "../../../modules/key-vault"

  name                = "kv-talos-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.network.name

  # Access policies for managed identities
  access_policies = [
    {
      name                    = "control-plane"
      object_id               = azurerm_user_assigned_identity.control_plane.principal_id
      secret_permissions      = ["Get", "List"]
      key_permissions         = []
      certificate_permissions = []
    },
    {
      name                    = "workers"
      object_id               = azurerm_user_assigned_identity.workers.principal_id
      secret_permissions      = ["Get", "List"]
      key_permissions         = []
      certificate_permissions = []
    }
  ]

  tags = var.tags
}
