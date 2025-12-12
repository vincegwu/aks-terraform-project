output "aks_name" {
  value = module.aks.aks_cluster_name
}

output "aks_cluster_name" {
  value       = module.aks.aks_cluster_name
  description = "AKS cluster name for kubectl/CLI access"
}

output "aks_fqdn" {
  value = module.aks.aks_fqdn
}

output "resource_group_name" {
  value       = module.network.resource_group_name
  description = "Resource group name for all resources"
}

output "acr_name" {
  value = module.acr.acr_name
}

output "acr_login_server" {
  value = module.acr.acr_login_server
}

output "keyvault_name" {
  value = module.keyvault.keyvault_name
}

output "keyvault_uri" {
  value = module.keyvault.keyvault_uri
}

output "mysql_name" {
  value = module.mysql.mysql_name
}

output "mysql_fqdn" {
  value = module.mysql.mysql_fqdn
}

output "vnet_id" {
  value = module.network.vnet_id
}

output "subnet_ids" {
  value = module.network.subnet_ids
}
