variable "subnet_ids" {
  type        = map(string)
  description = "Map of subnet IDs from network module"
}
variable "resource_group_name" {
  type        = string
  description = "Resource group name from network module"
}

variable "vnet_id" {
  type        = string
  description = "VNet ID for Private DNS zone link"
}

variable "project_name" { type = string }
variable "environment" { type = string }
variable "location" { type = string }

variable "unique_suffix" {
  type        = string
  description = "Unique suffix for globally unique MySQL server name"
  default     = ""
}

variable "mysql_admin_username" { type = string }
variable "mysql_admin_password" { type = string }

variable "mysql_sku_name" {
  description = "SKU name for MySQL Flexible Server (e.g., GP_Standard_D2ds_v4 for GeneralPurpose)."
  type        = string
  # Use a provider-compatible SKU. Format: <tier>_<family>_<version>
  default = "GP_Standard_D2ds_v4"
}
