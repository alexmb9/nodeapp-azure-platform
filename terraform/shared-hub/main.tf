#shared resource group
resource "azurerm_resource_group" "shared" {
  name     = "rg-shared-hub-prod"
  location = var.location
  tags     = var.tags
}

#vhub net
resource "azurerm_virtual_network" "hub" {
  name                = var.hub_vnet_name
  location            = azurerm_resource_group.shared.location
  resource_group_name = azurerm_resource_group.shared.name
  address_space       = var.hub_vnet_cidr
  tags                = var.tags
}

#firewall subnet
resource "azurerm_subnet" "azure_firewall_subnet" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.shared.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.fw_subnet_cidr]
}

#firewall public IP address
resource "azurerm_public_ip" "fw_pip" {
  name                = var.fw_public_ip_name
  location            = azurerm_resource_group.shared.location
  resource_group_name = azurerm_resource_group.shared.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

#azure firewall and IP configuration
resource "azurerm_firewall" "fw" {
  name                = var.fw_name
  location            = azurerm_resource_group.shared.location
  resource_group_name = azurerm_resource_group.shared.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"  # keep cost down; can change later
  tags                = var.tags

  ip_configuration {
    name                 = "ipconfig"
    subnet_id            = azurerm_subnet.azure_firewall_subnet.id
    public_ip_address_id = azurerm_public_ip.fw_pip.id
  }
}

#log analytic workspace
resource "azurerm_log_analytics_workspace" "law" {
  name                = var.log_analytics_name
  location            = azurerm_resource_group.shared.location
  resource_group_name = azurerm_resource_group.shared.name

  sku               = var.log_analytics_sku
  retention_in_days = var.log_retention_days

  tags = var.tags
}