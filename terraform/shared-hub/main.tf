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