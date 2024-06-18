terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
    zpa = {
      source = "zscaler/zpa"
      version = "~> 3.0.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
  client_id     = var.azure_client_id
  client_secret = var.azure_client_secret
  tenant_id     = var.azure_tenant_id
}

resource "azurerm_resource_group" "rg" {
  name     = var.azure_rg_name
  location = var.azure_region
}

resource "azurerm_network_security_group" "security_group" {
  name                = "security-group"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = [var.azure_vnet_cidr]
}

resource "azurerm_subnet" pub_subnet {
  name           = "pub_subnet"
  address_prefixes = [var.azure_pub_subnet_cidr]
  resource_group_name = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
}

resource "azurerm_subnet" pri_subnet1 {
  name           = "pri_subnet1"
  address_prefixes = [var.azure_pri1_subnet_cidr]
  resource_group_name = azurerm_resource_group.rg.name
   virtual_network_name = azurerm_virtual_network.vnet.name
}

resource "azurerm_subnet" pri_subnet2 {
  name           = "pri_subnet2"
  address_prefixes = [var.azure_pri2_subnet_cidr]
  resource_group_name = azurerm_resource_group.rg.name
   virtual_network_name = azurerm_virtual_network.vnet.name
}

# public subnet用のルーティングテーブル
resource "azurerm_route_table" "public_route_table" {
  name         = "public_route_table"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# デフォルトルートをインターネットゲートウェイに設定
resource "azurerm_route" "public_route" {
  name         = "public_route"
  resource_group_name = azurerm_resource_group.rg.name
  route_table_name = azurerm_route_table.public_route_table.name
  address_prefix = "0.0.0.0/0"
  next_hop_type = "Internet"
}

#ルーティングテーブルをサブネットに紐付け
resource "azurerm_subnet_route_table_association" "public" {
  subnet_id = azurerm_subnet.pub_subnet.id
  route_table_id = azurerm_route_table.public_route_table.id
}

# private subnet用のルーティングテーブル
resource "azurerm_route_table" "private_route_table" {
  name         = "private_route_table"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}


################################################################################
#NAT Gatewayの作成
################################################################################
# Public IP address for NAT gateway
resource "azurerm_public_ip" "public_ip_natgw" {
  name                = "public-ip-nat"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# NAT Gateway
resource "azurerm_nat_gateway" "natgw" {
  name                = "nat-gateway"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Associate NAT Gateway with Public IP
resource "azurerm_nat_gateway_public_ip_association" "natgw_ip" {
  nat_gateway_id       = azurerm_nat_gateway.natgw.id
  public_ip_address_id = azurerm_public_ip.public_ip_natgw.id
}

# Associate NAT Gateway with Subnet
resource "azurerm_subnet_nat_gateway_association" "natgw_subnet1" {
  subnet_id      = azurerm_subnet.pri_subnet1.id
  nat_gateway_id = azurerm_nat_gateway.natgw.id
}

# Associate NAT Gateway with Subnet
resource "azurerm_subnet_nat_gateway_association" "natgw_subnet2" {
  subnet_id      = azurerm_subnet.pri_subnet2.id
  nat_gateway_id = azurerm_nat_gateway.natgw.id
}

resource "tls_private_key" "key" {
  algorithm = var.azure_tls_key_algorithm
}