module "network" {
  source        = "./modules/network"
  project_name  = var.project_name
  environment   = var.environment
  location      = var.location
  address_space = var.address_space
  subnets       = var.subnets
  enable_udr    = true
}

module "aks" {
  source                 = "./modules/aks"
  project_name           = var.project_name
  environment            = var.environment
  location               = var.location
  aks_min_count          = var.aks_min_count
  aks_max_count          = var.aks_max_count
  subnet_ids             = module.network.subnet_ids
  resource_group_name    = module.network.resource_group_name
  enable_private_cluster = var.enable_private_aks_cluster
  acr_id                 = module.acr.acr_id
}

module "mysql" {
  source               = "./modules/mysql"
  project_name         = var.project_name
  environment          = var.environment
  location             = var.location
  mysql_admin_username = var.mysql_admin_username
  mysql_admin_password = var.mysql_admin_password
  subnet_ids           = module.network.subnet_ids
  resource_group_name  = module.network.resource_group_name
  vnet_id              = module.network.vnet_id
  unique_suffix        = local.unique_suffix
}

module "acr" {
  source                  = "./modules/acr"
  project_name            = var.project_name
  environment             = var.environment
  location                = var.location
  resource_group_name     = module.network.resource_group_name
  private_subnet_id       = lookup(module.network.subnet_ids, "aks", "")
  enable_private_endpoint = var.create_private_endpoints
  unique_suffix           = local.unique_suffix
}

module "keyvault" {
  source              = "./modules/keyvault"
  project_name        = var.project_name
  environment         = var.environment
  location            = var.location
  sku                 = var.kv_sku
  resource_group_name = module.network.resource_group_name
  tags = {
    environment = var.environment
    project     = var.project_name
  }
  private_subnet_id       = lookup(module.network.subnet_ids, "aks", "")
  enable_private_endpoint = var.create_private_endpoints
  allowed_ip_ranges       = [] # Empty list for now, can be configured per environment
}
