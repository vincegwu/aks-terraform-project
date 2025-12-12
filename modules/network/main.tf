# Create Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "${var.project_name}-${var.environment}-rg"
  location = var.location
}

# Create Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.project_name}-${var.environment}-vnet"
  address_space       = var.address_space
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create NSG for each subnet
resource "azurerm_network_security_group" "nsgs" {
  for_each = var.subnets

  name                = "${var.project_name}-${var.environment}-${each.key}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create Subnets with NSG attached
resource "azurerm_subnet" "subnets" {
  for_each             = var.subnets
  name                 = each.key
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = each.value.address_prefixes
}

# Associate NSG with Subnets
resource "azurerm_subnet_network_security_group_association" "subnet_nsg_assoc" {
  for_each                  = var.subnets
  subnet_id                 = azurerm_subnet.subnets[each.key].id
  network_security_group_id = azurerm_network_security_group.nsgs[each.key].id
}

# Network Security Rules
# Allow DB (MySQL) traffic only from the AKS subnet to the database subnet
resource "azurerm_network_security_rule" "db_allow_from_aks" {
  count                  = contains(keys(var.subnets), "database") && contains(keys(var.subnets), "aks") ? 1 : 0
  name                   = "${var.project_name}-${var.environment}-allow-db-from-aks"
  priority               = 100
  direction              = "Inbound"
  access                 = "Allow"
  protocol               = "Tcp"
  source_port_range      = "*"
  destination_port_range = "3306"

  # Use the AKS subnet first prefix as the source CIDR
  source_address_prefix      = azurerm_subnet.subnets["aks"].address_prefixes[0]
  destination_address_prefix = azurerm_subnet.subnets["database"].address_prefixes[0]

  network_security_group_name = azurerm_network_security_group.nsgs["database"].name
  resource_group_name         = azurerm_resource_group.rg.name
}

# AKS inbound hardening: allow Azure LB and VNet, then deny Internet
resource "azurerm_network_security_rule" "aks_allow_azure_lb" {
  count                  = contains(keys(var.subnets), "aks") ? 1 : 0
  name                   = "${var.project_name}-${var.environment}-aks-allow-azurelb"
  priority               = 100
  direction              = "Inbound"
  access                 = "Allow"
  protocol               = "*"
  source_port_range      = "*"
  destination_port_range = "*"

  source_address_prefix      = "AzureLoadBalancer"
  destination_address_prefix = azurerm_subnet.subnets["aks"].address_prefixes[0]

  network_security_group_name = azurerm_network_security_group.nsgs["aks"].name
  resource_group_name         = azurerm_resource_group.rg.name
}

resource "azurerm_network_security_rule" "aks_allow_vnet" {
  count                  = contains(keys(var.subnets), "aks") ? 1 : 0
  name                   = "${var.project_name}-${var.environment}-aks-allow-vnet"
  priority               = 110
  direction              = "Inbound"
  access                 = "Allow"
  protocol               = "*"
  source_port_range      = "*"
  destination_port_range = "*"

  source_address_prefix      = "VirtualNetwork"
  destination_address_prefix = azurerm_subnet.subnets["aks"].address_prefixes[0]

  network_security_group_name = azurerm_network_security_group.nsgs["aks"].name
  resource_group_name         = azurerm_resource_group.rg.name
}

resource "azurerm_network_security_rule" "aks_deny_internet" {
  count                  = contains(keys(var.subnets), "aks") ? 1 : 0
  name                   = "${var.project_name}-${var.environment}-aks-deny-internet"
  priority               = 120
  direction              = "Inbound"
  access                 = "Deny"
  protocol               = "*"
  source_port_range      = "*"
  destination_port_range = "*"

  source_address_prefix      = "Internet"
  destination_address_prefix = azurerm_subnet.subnets["aks"].address_prefixes[0]

  network_security_group_name = azurerm_network_security_group.nsgs["aks"].name
  resource_group_name         = azurerm_resource_group.rg.name
}

# Optional: User Defined Route (UDR) for private subnets
resource "azurerm_route_table" "private" {
  count               = var.enable_udr ? 2 : 0
  name                = "${var.project_name}-${var.environment}-private-rt-${count.index + 1}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet_route_table_association" "private_assoc" {
  for_each       = { for k, v in azurerm_subnet.subnets : k => v if k == "aks" || k == "database" }
  subnet_id      = each.value.id
  route_table_id = element(azurerm_route_table.private[*].id, 0) # simple association, can customize per subnet
}

# NAT Gateway resources for egress (created only when an `egress` subnet is defined)
resource "azurerm_public_ip" "nat_ip" {
  count               = contains(keys(var.subnets), "egress") ? 1 : 0
  name                = "${var.project_name}-${var.environment}-nat-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_nat_gateway" "nat" {
  count               = contains(keys(var.subnets), "egress") ? 1 : 0
  name                = "${var.project_name}-${var.environment}-nat"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "Standard"
}

# Associate Public IP(s) to the NAT Gateway using the association resource
resource "azurerm_nat_gateway_public_ip_association" "nat_ip_assoc" {
  count = contains(keys(var.subnets), "egress") ? length(azurerm_public_ip.nat_ip) : 0

  nat_gateway_id       = azurerm_nat_gateway.nat[0].id
  public_ip_address_id = element(azurerm_public_ip.nat_ip[*].id, count.index)
}

# Associate the NAT gateway with the egress subnet when present
resource "azurerm_subnet_nat_gateway_association" "egress_assoc" {
  count = contains(keys(var.subnets), "egress") ? 1 : 0

  subnet_id      = azurerm_subnet.subnets["egress"].id
  nat_gateway_id = azurerm_nat_gateway.nat[0].id
}

# Also attach the NAT Gateway to the AKS subnet so AKS uses the stable NAT egress IPs
resource "azurerm_subnet_nat_gateway_association" "aks_assoc" {
  count = contains(keys(var.subnets), "egress") && contains(keys(var.subnets), "aks") ? 1 : 0

  subnet_id      = azurerm_subnet.subnets["aks"].id
  nat_gateway_id = azurerm_nat_gateway.nat[0].id
  #nat_gateway_id = azurerm_nat_gateway.nat[0].id
}

