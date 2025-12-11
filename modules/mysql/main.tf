resource "azurerm_mysql_flexible_server" "mysql" {
  name                   = var.unique_suffix != "" ? "${var.project_name}-${var.environment}-mysql-${var.unique_suffix}" : "${var.project_name}-${var.environment}-mysql"
  location               = var.location
  resource_group_name    = var.resource_group_name
  administrator_login    = var.mysql_admin_username
  administrator_password = var.mysql_admin_password
  # Use a provider-compatible MySQL version and SKU. Adjust `mysql_sku_name` in
  # `variables.tf` if you need a different SKU.
  version  = "8.0.21"
  sku_name = var.mysql_sku_name


  backup_retention_days        = 7
  geo_redundant_backup_enabled = false

  # `public_network_access_enabled` is managed by the provider and cannot be set
  # directly in some provider versions, so remove explicit configuration.
}

# Private DNS Zone for MySQL Private Link
resource "azurerm_private_dns_zone" "mysql" {
  name                = "privatelink.mysql.database.azure.com"
  resource_group_name = var.resource_group_name
}

# Link Private DNS Zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "mysql" {
  name                  = "${var.project_name}-${var.environment}-mysql-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.mysql.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
}

# Private endpoint to database subnet
resource "azurerm_private_endpoint" "db_pe" {
  name                = "${var.project_name}-${var.environment}-db-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_ids["database"]

  private_service_connection {
    name                           = "${var.project_name}-${var.environment}-db-psc"
    is_manual_connection           = false
    private_connection_resource_id = azurerm_mysql_flexible_server.mysql.id
    subresource_names              = ["mysqlServer"]
  }

  private_dns_zone_group {
    name                 = "mysql-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.mysql.id]
  }

  depends_on = [azurerm_private_dns_zone_virtual_network_link.mysql]
}
