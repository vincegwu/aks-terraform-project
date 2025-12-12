output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "vnet_id" {
  value = azurerm_virtual_network.vnet.id
}

output "subnet_ids" {
  value = { for k, v in azurerm_subnet.subnets : k => v.id }
}

output "nsg_ids" {
  value = { for k, v in azurerm_network_security_group.nsgs : k => v.id }
}

output "route_table_ids" {
  value = length(azurerm_route_table.private) > 0 ? azurerm_route_table.private[*].id : []
}
