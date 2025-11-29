resource "azurerm_mysql_flexible_server" "mysql" {
  name                = "${var.project_name}-${var.environment}-mysql"
  location            = var.location
  resource_group_name = var.resource_group_name
  administrator_login = var.mysql_admin_username
  administrator_password = var.mysql_admin_password
  # Use a provider-compatible MySQL version and SKU. Adjust `mysql_sku_name` in
  # `variables.tf` if you need a different SKU.
  version  = "8.0.21"
  sku_name = var.mysql_sku_name

  #storage_mb            = 5120
  backup_retention_days = 7
  geo_redundant_backup_enabled = false

  # `public_network_access_enabled` is managed by the provider and cannot be set
  # directly in some provider versions, so remove explicit configuration.
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
}

// Private DNS handling for MySQL removed here — module creates the Private
// Endpoint only. If you need private DNS records, create them in a separate
// DNS management module or via a centralized process that targets your
// environment's provider version.
