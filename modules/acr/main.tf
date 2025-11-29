resource "azurerm_container_registry" "acr" {
  name                = "${var.project_name}${var.environment}acr"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.acr_sku
  admin_enabled       = false

  dynamic "georeplications" {
    for_each = var.acr_sku == "Premium" ? [1] : []
    content {
      location                = var.secondary_location
      zone_redundancy_enabled = true
    }
  }

  tags = {
    environment = var.environment
    project     = var.project_name
  }
}

# Optional Private Endpoint for ACR
resource "azurerm_private_endpoint" "acr_pe" {
  count               = var.enable_private_endpoint ? 1 : 0
  name                = "${var.project_name}-${var.environment}-acr-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_subnet_id

  private_service_connection {
    name                           = "${var.project_name}-${var.environment}-acr-psc"
    is_manual_connection           = false
    private_connection_resource_id = azurerm_container_registry.acr.id
    subresource_names              = ["registry"]
  }
}

// Private DNS handling for ACR was removed — module creates only the optional
// Private Endpoint. Manage private DNS outside this module if needed.

// ...existing code...

// Repository resources removed: `azurerm_container_registry_repository` is unsupported
// Repositories are created on demand when pushing images to ACR. If you need
// lifecycle rules or retention policies, use the `azurerm_container_registry_retention_policy`
// resource or manage repositories via the Azure CLI / Az API.
