project_name = "cloudproj"
environment  = "prod"
location     = "westus2"

address_space = ["10.30.0.0/16"]

subnets = {
  egress   = { address_prefixes = ["10.30.1.0/24"] }
  aks      = { address_prefixes = ["10.30.2.0/24"] }
  database = { address_prefixes = ["10.30.3.0/24"] }
}


aks_node_count = 5

mysql_admin_username = "adminuser"
# Do NOT commit secrets. Set `mysql_admin_password` in CI secret store
# Example: in GitHub Actions use `${{ secrets.PROD_MYSQL_PASSWORD }}` and pass
# it as `-var="mysql_admin_password=${{ secrets.PROD_MYSQL_PASSWORD }}"`
# mysql_admin_password = "<SET_IN_CI>"

# Security settings - ENABLED for prod environment (production-grade security)
create_private_endpoints   = true
enable_private_aks_cluster = true
