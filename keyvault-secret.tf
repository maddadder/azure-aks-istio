############################
## KeyVault Secret - Main ##
############################

# Variable for Certificate Name
locals {
  certificate-name = "${var.company}-RootCert.crt"
}

# Create a Secret for the VPN Root certificate
resource "azurerm_key_vault_secret" "vpn-root-certificate" {
  count         = var.vpn_instance_count
  depends_on    = [azurerm_key_vault.leenet-keyvault]

  name          = "vpn-root-certificate"
  value         = filebase64(local.certificate-name)
  key_vault_id  = azurerm_key_vault.leenet-keyvault[0].id

  tags = {
    environment = var.environment
  }
}

