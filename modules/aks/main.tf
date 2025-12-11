resource "azurerm_kubernetes_cluster" "aks" {
  name                = "${var.project_name}-${var.environment}-aks"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "${var.project_name}-${var.environment}-aks"

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

  azure_policy_enabled              = true
  role_based_access_control_enabled = true

  tags = {
    environment = var.environment
    project     = var.project_name
    # project     = var.project_name
  }
}