data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "kv" {
  name                        = "${var.project_name}-${var.environment}-kv"
  location                    = var.location
  resource_group_name         = var.resource_group_name
  sku_name                    = var.sku
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = true
  tags                        = var.tags
}

# Optional Private Endpoint for Key Vault
resource "azurerm_private_endpoint" "kv_pe" {
  count               = var.enable_private_endpoint ? 1 : 0
  name                = "${var.project_name}-${var.environment}-kv-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_subnet_id

  private_service_connection {
    name                           = "${var.project_name}-${var.environment}-kv-psc"
    is_manual_connection           = false
    private_connection_resource_id = azurerm_key_vault.kv.id
    subresource_names              = ["vault"]
  }
}

# Optional Private DNS zone and link for Key Vault privatelink
// Private DNS handling for Key Vault was removed — module creates only the
// optional Private Endpoint. Manage private DNS outside this module if needed.