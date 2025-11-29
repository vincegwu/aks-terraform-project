variable "project_name" {}
variable "environment" {}
variable "location" {}
variable "sku" {}
variable "tags" {}

variable "resource_group_name" {
  type        = string
  description = "Resource group name from network module"
}

variable "private_subnet_id" {
  type        = string
  description = "Optional subnet ID for placing a Private Endpoint for Key Vault (pass module.network.subnet_ids[\"aks\"] or similar)."
  default     = ""
}

variable "enable_private_endpoint" {
  type        = bool
  description = "Set to true to create an optional Private Endpoint for Key Vault. Keep false to skip creating the Private Endpoint."
  default     = false
}
