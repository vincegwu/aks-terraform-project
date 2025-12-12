output "mysql_name" {
  value = azurerm_mysql_flexible_server.mysql.name
}

output "mysql_fqdn" {
  value = azurerm_mysql_flexible_server.mysql.fqdn
}

output "mysql_id" {
  value       = azurerm_mysql_flexible_server.mysql.id
  description = "The ID of the MySQL Flexible Server"
}
