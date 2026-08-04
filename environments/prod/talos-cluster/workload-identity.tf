# Workload Identity Federation
#
# Federated credentials let in-cluster service accounts authenticate to Azure
# as the user-assigned identities created in the network-and-security layer.
#
# Prerequisites:
#   1. The matching identity created in network-and-security
#      (enable_cert_manager_identity / enable_external_dns_identity = true).
#   2. OIDC issuer configured in the Talos cluster (available after bootstrap).
#   3. oidc_issuer_url provided as a variable.

# cert-manager federated credential (DNS-01 on the public zone)
resource "azurerm_federated_identity_credential" "cert_manager" {
  count                     = var.enable_cert_manager_federation && var.oidc_issuer_url != "" ? 1 : 0
  name                      = "cert-manager-federated"
  user_assigned_identity_id = data.azurerm_user_assigned_identity.cert_manager[0].id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = var.oidc_issuer_url
  subject                   = var.cert_manager_service_account
}

# external-dns federated credential (self-service records in the apps zone, Change C)
resource "azurerm_federated_identity_credential" "external_dns" {
  count                     = var.enable_external_dns_federation && var.oidc_issuer_url != "" ? 1 : 0
  name                      = "external-dns-federated"
  user_assigned_identity_id = data.azurerm_user_assigned_identity.external_dns[0].id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = var.oidc_issuer_url
  subject                   = var.external_dns_service_account
}
