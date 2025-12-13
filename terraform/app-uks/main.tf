#resource group for 
resource "azurerm_resource_group" "app" {
  name     = "rg-${lower(var.app_name)}-${lower(var.environment)}-${lower(var.region_code)}"
  location = var.location
  tags     = var.tags
}

#App Vnet and subnets
resource "azurerm_virtual_network" "app" {
  name                = var.app_vnet_name
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  address_space       = var.app_vnet_cidr
  tags                = var.tags
}

resource "azurerm_subnet" "appgw" {
  name                 = "snet-appgw"
  resource_group_name  = azurerm_resource_group.app.name
  virtual_network_name = azurerm_virtual_network.app.name
  address_prefixes     = [var.subnet_appgw_cidr]
}

resource "azurerm_subnet" "app" {
  name                 = "snet-app"
  resource_group_name  = azurerm_resource_group.app.name
  virtual_network_name = azurerm_virtual_network.app.name
  address_prefixes     = [var.subnet_app_cidr]
}

#Internal application gateway, private frontend
resource "azurerm_application_gateway" "appgw" {
  name                = var.appgw_name
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name

  sku {
    name     = var.appgw_sku        # "Standard_v2" or "WAF_v2"
    tier     = var.appgw_sku
    capacity = var.appgw_capacity
  }

  gateway_ip_configuration {
    name      = "gwipcfg"
    subnet_id = azurerm_subnet.appgw.id
  }

  frontend_port {
    name = "feport-https"
    port = 443
  }

  frontend_ip_configuration {
    name                          = "feip-private"
    subnet_id                     = azurerm_subnet.appgw.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.appgw_private_ip
  }

  # Placeholder backend (we’ll update later to point to the App Service private endpoint FQDN)
  backend_address_pool {
    name = "be-pool"
  }

  backend_http_settings {
    name                  = "be-https"
    protocol              = "Https"
    port                  = 443
    cookie_based_affinity = "Disabled"
    request_timeout       = 30

    # When we wire App Service, you typically need host_name / pick_host_name_from_backend_address
    # host_name = "yourapp.azurewebsites.net"
  }

  http_listener {
    name                           = "listener-https"
    frontend_ip_configuration_name = "feip-private"
    frontend_port_name             = "feport-https"
    protocol                       = "Https"

    # For now we’ll run without TLS cert wiring.
    # Next step: attach cert from Key Vault (recommended).
  }

  request_routing_rule {
    name                       = "rule-https"
    rule_type                  = "Basic"
    http_listener_name         = "listener-https"
    backend_address_pool_name  = "be-pool"
    backend_http_settings_name = "be-https"
    priority                   = 10
  }

  tags = var.tags
}

