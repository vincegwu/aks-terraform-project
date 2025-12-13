data "azurerm_client_config" "current" {}

resource "azurerm_kubernetes_cluster" "aks" {
  name                    = "${var.project_name}-${var.environment}-aks"
  location                = var.location
  resource_group_name     = var.resource_group_name
  dns_prefix              = "${var.project_name}-${var.environment}-aks"
  private_cluster_enabled = var.enable_private_cluster
  local_account_disabled  = false # Enable local accounts for CI/CD access

  default_node_pool {
    name                         = "default"
    vm_size                      = var.vm_size
    vnet_subnet_id               = var.subnet_ids["aks"]
    auto_scaling_enabled         = true
    min_count                    = var.aks_min_count
    max_count                    = var.aks_max_count
    zones                        = length(var.availability_zones) > 0 ? var.availability_zones : null
    only_critical_addons_enabled = false
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
    outbound_type     = "loadBalancer"
  }

  azure_active_directory_role_based_access_control {
    tenant_id          = data.azurerm_client_config.current.tenant_id
    azure_rbac_enabled = true
  }

  azure_policy_enabled              = true
  role_based_access_control_enabled = true

  tags = {
    environment = var.environment
    project     = var.project_name
  }
}

# Grant Azure Kubernetes Service Cluster Admin Role to the current user/service principal
# This allows CI/CD pipelines to manage the cluster
resource "azurerm_role_assignment" "aks_admin" {
  count                = var.create_role_assignment ? 1 : 0
  scope                = azurerm_kubernetes_cluster.aks.id
  role_definition_name = "Azure Kubernetes Service Cluster Admin Role"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Grant AKS managed identity permission to pull images from ACR
resource "azurerm_role_assignment" "aks_acr_pull" {
  count                = var.create_acr_role_assignment && var.acr_id != "" ? 1 : 0
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}
