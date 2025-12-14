resource "azurerm_mysql_flexible_server" "mysql" {
  name                   = var.unique_suffix != "" ? "${var.project_name}-${var.environment}-mysql-${var.unique_suffix}" : "${var.project_name}-${var.environment}-mysql"
  location               = var.location
  resource_group_name    = var.resource_group_name
  administrator_login    = var.mysql_admin_username
  administrator_password = var.mysql_admin_password
  version                = "8.0.21"
  sku_name               = var.mysql_sku_name

  backup_retention_days        = 7
  geo_redundant_backup_enabled = false
}

# Create the database
resource "azurerm_mysql_flexible_database" "book_review_db" {
  name                = "book_review_db"
  resource_group_name = var.resource_group_name
  server_name         = azurerm_mysql_flexible_server.mysql.name
  charset             = "utf8mb4"
  collation           = "utf8mb4_unicode_ci"
}

# Firewall rule to allow Azure services (when not using private endpoint)
resource "azurerm_mysql_flexible_server_firewall_rule" "allow_azure_services" {
  count               = var.enable_private_endpoint ? 0 : 1
  name                = "AllowAzureServices"
  resource_group_name = var.resource_group_name
  server_name         = azurerm_mysql_flexible_server.mysql.name
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"
}

# Private DNS Zone for MySQL Private Link
resource "azurerm_private_dns_zone" "mysql" {
  count               = var.enable_private_endpoint ? 1 : 0
  name                = "privatelink.mysql.database.azure.com"
  resource_group_name = var.resource_group_name
}

# Link Private DNS Zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "mysql" {
  count                 = var.enable_private_endpoint ? 1 : 0
  name                  = "${var.project_name}-${var.environment}-mysql-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.mysql[0].name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
}

# Private endpoint to database subnet
resource "azurerm_private_endpoint" "db_pe" {
  count               = var.enable_private_endpoint ? 1 : 0
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
    private_dns_zone_ids = [azurerm_private_dns_zone.mysql[0].id]
  }

  depends_on = [azurerm_private_dns_zone_virtual_network_link.mysql]
}
