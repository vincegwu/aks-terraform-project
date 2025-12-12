variable "project_name" { type = string }
variable "environment" { type = string }
variable "location" { type = string }

variable "unique_suffix" {
  type        = string
  description = "Unique suffix for globally unique ACR name  of  the  suffix  name "
  default     = ""
}

variable "resource_group_name" {
  type        = string
  description = "Resource group name from network module"
}

variable "private_subnet_id" {
  type        = string
  description = "Optional subnet ID for placing a Private Endpoint for ACR (pass module.network.subnet_ids[\"aks\"] or similar)."
  default     = ""
}

variable "enable_private_endpoint" {
  type        = bool
  description = "Set to true to create an optional Private Endpoint for ACR. Keep false to skip creating the Private Endpoint."
  default     = false
}

variable "secondary_location" {
  description = "Secondary Azure region for geo-replication"
  type        = string
  default     = "eastus2"
}

variable "acr_sku" {
  description = "SKU for Azure Container Registry. Use 'Premium' for geo-replication."
  type        = string
  default     = "Standard"
}