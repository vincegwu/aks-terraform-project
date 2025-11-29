variable "project_name" {}
variable "environment" {}

variable "location" {
  default = "eastus"
}

variable "address_space" {
  type = list(string)
}

variable "subnets" {
  type = map(object({
    address_prefixes = list(string)
  }))
}

variable "aks_node_count" {
  type    = number
  default = 2
}

variable "mysql_admin_username" {}
variable "mysql_admin_password" {
  sensitive = true
}

variable "kv_sku" {
  default = "standard"
}

variable "create_private_endpoints" {
  type        = bool
  description = "Global flag to enable creation of optional private endpoints for modules that support them (ACR, Key Vault). Set to true to create private endpoints."
  default     = false
}
