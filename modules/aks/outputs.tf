output "aks_cluster_name" {
  value = azurerm_kubernetes_cluster.aks.name
}

output "aks_kube_config" {
  # Use Azure AD kubeconfig (local accounts disabled)
  value     = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive = true
}

output "aks_fqdn" {
  value = azurerm_kubernetes_cluster.aks.fqdn
}

output "kubelet_identity_object_id" {
  description = "Object ID of the AKS kubelet identity"
  value       = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}

output "ingress_ip" {
  value       = azurerm_public_ip.aks_ingress_ip.ip_address
  description = "Static IP assigned to AKS Ingress"
}

output "ingress_dns_name" {
  value       = "${azurerm_dns_a_record.ingress.name}.${azurerm_dns_zone.book_review.name}"
  description = "Fully qualified domain name for the Ingress"
}

output "ingress_ip" {
  value = azurerm_public_ip.aks_ingress_ip.ip_address
}

output "ingress_fqdn" {
  value = "${var.ingress_subdomain}.${var.dns_zone_name}"
}