project_name = "cloudproj"
environment  = "dev"
location     = "australiacentral"

# Generate unique suffix for globally unique resources
# Use a random suffix or your initials + timestamp
# Example: "vgw" + current date or random number

address_space = ["10.10.0.0/16"]

subnets = {
  egress            = { address_prefixes = ["10.10.1.0/24"] } # Egress subnet for NAT Gateway
  aks               = { address_prefixes = ["10.10.2.0/24"] } # Private subnet for AKS node pools
  database          = { address_prefixes = ["10.10.3.0/24"] } # Private subnet for MySQL (reserved)
  private-endpoints = { address_prefixes = ["10.10.4.0/24"] } # Dedicated subnet for private endpoints
}


aks_min_count = 3
aks_max_count = 5

mysql_admin_username = "adminuser"
mysql_admin_password = "DevStrongPassword123!"

# Security settings - DISABLED for dev environment (easier local access)
create_private_endpoints   = false
enable_private_aks_cluster = false

# ACR Integration - Automatically attach ACR to AKS
create_acr_role_assignment = true # Enabled - service principal now has User Access Administrator role

# AKS Access - Grant service principal admin access to manage AKS cluster
# Set to false temporarily if role assignment already exists to avoid 409 conflict
create_aks_admin_role_assignment = false # Role assignment already exists in Azure

# Optional: Override ACR SKU (default is "Standard"; use "Premium" for geo-replication)
# acr_sku = "Standard"

# Optional: Override MySQL SKU (default is "GP_Standard_D2ds_v4"; adjust per your subscription)
# mysql_sku_name = "GP_Standard_D2ds_v4"
