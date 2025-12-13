project_name = "cloudproj"
environment  = "dev"
location     = "australiacentral"

# Generate unique suffix for globally unique resources
# Use a random suffix or your initials + timestamp
# Example: "vgw" + current date or random number
resource_suffix = "" # Change this to make resources unique

address_space = ["10.10.0.0/16"]

subnets = {
  egress   = { address_prefixes = ["10.10.1.0/24"] } # Egress subnet for NAT Gateway
  aks      = { address_prefixes = ["10.10.2.0/24"] } # Private subnet for AKS node pools
  database = { address_prefixes = ["10.10.3.0/24"] } # Private subnet for MySQL
}


aks_min_count = 3
aks_max_count = 5

mysql_admin_username = "adminuser"
mysql_admin_password = "DevStrongPassword123!"

# Security settings - DISABLED for dev environment (easier local access)
create_private_endpoints   = false
enable_private_aks_cluster = false

# Optional: Override ACR SKU (default is "Standard"; use "Premium" for geo-replication)
# acr_sku = "Standard"

# Optional: Override MySQL SKU (default is "GP_Standard_D2ds_v4"; adjust per your subscription)
# mysql_sku_name = "GP_Standard_D2ds_v4"
