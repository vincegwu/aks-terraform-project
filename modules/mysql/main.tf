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

  # VNet Integration: Inject MySQL server into the database subnet
  # This is the recommended approach for Azure MySQL Flexible Server
  delegated_subnet_id = var.subnet_ids["database"]
  private_dns_zone_id = azurerm_private_dns_zone.mysql.id

  backup_retention_days        = 7
  geo_redundant_backup_enabled = false

  depends_on = [azurerm_private_dns_zone_virtual_network_link.mysql]
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

# Private endpoint is NOT needed when using VNet Integration (delegated_subnet_id)
# VNet Integration provides direct network injection into the database subnet
# which is more secure and eliminates the need for private endpoints

# Configure MySQL server parameters to prevent connection timeouts
resource "azurerm_mysql_flexible_server_configuration" "wait_timeout" {
  name                = "wait_timeout"
  resource_group_name = var.resource_group_name
  server_name         = azurerm_mysql_flexible_server.mysql.name
  value               = tostring(var.mysql_wait_timeout)
}

resource "azurerm_mysql_flexible_server_configuration" "interactive_timeout" {
  name                = "interactive_timeout"
  resource_group_name = var.resource_group_name
  server_name         = azurerm_mysql_flexible_server.mysql.name
  value               = tostring(var.mysql_interactive_timeout)
}

resource "azurerm_mysql_flexible_server_configuration" "connect_timeout" {
  name                = "connect_timeout"
  resource_group_name = var.resource_group_name
  server_name         = azurerm_mysql_flexible_server.mysql.name
  value               = tostring(var.mysql_connect_timeout)
}

resource "azurerm_mysql_flexible_server_configuration" "net_read_timeout" {
  name                = "net_read_timeout"
  resource_group_name = var.resource_group_name
  server_name         = azurerm_mysql_flexible_server.mysql.name
  value               = tostring(var.mysql_net_read_timeout)
}

resource "azurerm_mysql_flexible_server_configuration" "net_write_timeout" {
  name                = "net_write_timeout"
  resource_group_name = var.resource_group_name
  server_name         = azurerm_mysql_flexible_server.mysql.name
  value               = tostring(var.mysql_net_write_timeout)
}
