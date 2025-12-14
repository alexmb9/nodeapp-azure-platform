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

  ssl_policy {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20170401S"
  }


  frontend_ip_configuration {
    name                 = "feip-public-unused"
    public_ip_address_id = azurerm_public_ip.appgw_pip.id
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

      identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.appgw.id]
  }

    ssl_certificate {
    name                = "kv-ssl"
    key_vault_secret_id = azurerm_key_vault_certificate.appgw.secret_id
  }

#do not create any listener using feip-public-unused due to issue-1
  http_listener {
    name                           = "listener-https"
    frontend_ip_configuration_name = "feip-private"
    frontend_port_name             = "feport-https"
    protocol                       = "Https"
    ssl_certificate_name           = "kv-ssl"

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

#data sources, identity, key vault permissions for appgw

data "azurerm_key_vault" "shared" {
  name                = var.shared_kv_name
  resource_group_name = var.shared_kv_rg
}

resource "azurerm_user_assigned_identity" "appgw" {
  name                = "id-appgw-${lower(var.app_name)}-${lower(var.environment)}-${lower(var.region_code)}"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  tags                = var.tags
}

# Allow App Gateway identity to read Key Vault secrets (RBAC-enabled vault)
resource "azurerm_role_assignment" "appgw_kv_secrets_user" {
  scope                = data.azurerm_key_vault.shared.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.appgw.principal_id
}

#self-signed certificate
resource "azurerm_key_vault_certificate" "appgw" {
  name         = var.appgw_cert_name
  key_vault_id = data.azurerm_key_vault.shared.id

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      exportable = true
      key_type   = "RSA"
      key_size   = 2048
      reuse_key  = true
    }

    secret_properties {
      content_type = "application/x-pkcs12"
    }

    x509_certificate_properties {
      subject            = "CN=internal.nodeapp.local"
      validity_in_months = 12
      key_usage = [
        "digitalSignature",
        "keyEncipherment",
      ]
      extended_key_usage = ["1.3.6.1.5.5.7.3.1"] # serverAuth
    }

    lifetime_action {
      action {
        action_type = "AutoRenew"
      }
      trigger {
        days_before_expiry = 30
      }
    }
  }
}

##hacky fix for weird issue on SKU tier selection for app gateway, add a public IP, but still not exposed
##because nothing listens on the public front end - see issue #1 in github
resource "azurerm_public_ip" "appgw_pip" {
  name                = "pip-${var.appgw_name}"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}


##cmk and sql server
locals {
  sql_server_name = "sql-${lower(var.app_name)}-${lower(var.environment)}-${lower(var.region_code)}"
  sql_db_name     = "sqldb-${lower(var.app_name)}-${lower(var.environment)}"
  sql_cmk_key_name     = "cmk-sql-${lower(var.app_name)}-${lower(var.environment)}-${lower(var.region_code)}"
}

resource "azurerm_key_vault_key" "sql_cmk" {
  name         = local.sql_cmk_key_name
  key_vault_id = data.azurerm_key_vault.shared.id
  key_type     = "RSA"
  key_size     = 2048
  key_opts     = ["wrapKey", "unwrapKey"]
}

resource "azurerm_mssql_server" "sql" {
  name                         = local.sql_server_name
  resource_group_name          = azurerm_resource_group.app.name
  location                     = azurerm_resource_group.app.location
  version                      = "12.0"

  administrator_login          = var.sql_admin_login
  administrator_login_password = var.sql_admin_password

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

##creating the database
resource "azurerm_mssql_database" "db" {
  name      = local.sql_db_name
  server_id = azurerm_mssql_server.sql.id
  sku_name  = "Basic"

  depends_on = [azurerm_mssql_server_transparent_data_encryption.tde]
}

resource "azurerm_role_assignment" "sql_kv_crypto_user" {
  scope                = data.azurerm_key_vault.shared.id
  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = azurerm_mssql_server.sql.identity[0].principal_id
}

resource "azurerm_mssql_server_transparent_data_encryption" "tde" {
  server_id        = azurerm_mssql_server.sql.id
  key_vault_key_id = azurerm_key_vault_key.sql_cmk.id

  # Optional but nice for “bank-grade”:
  auto_rotation_enabled = true

  depends_on = [azurerm_role_assignment.sql_kv_crypto_user]
}







