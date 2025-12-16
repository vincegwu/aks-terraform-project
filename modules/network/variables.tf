variable "project_name" {
  type        = string
  description = "Project name prefix for resources"
}

variable "environment" {
  type        = string
  description = "Environment name (dev, stage, prod)"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "address_space" {
  type        = list(string)
  description = "VNet address space"
}

variable "subnets" {
  type = map(object({
    address_prefixes = list(string)
  }))
  description = "Subnets with address prefixes"
}

variable "enable_udr" {
  type        = bool
  description = "Enable UDR for private subnets"
  default     = true
}

variable "dns_zone_name" {
  description = "The DNS zone name to be used by the AKS module."
  type        = string
  default = "bookreview.dev"
}