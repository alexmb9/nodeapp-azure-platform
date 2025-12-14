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
  name                              = "snet-appgw"
  resource_group_name               = azurerm_resource_group.app.name
  virtual_network_name              = azurerm_virtual_network.app.name
  private_endpoint_network_policies = "Enabled"
  address_prefixes                  = [var.subnet_appgw_cidr]
}

resource "azurerm_subnet" "app" {
  name                              = "snet-app"
  resource_group_name               = azurerm_resource_group.app.name
  virtual_network_name              = azurerm_virtual_network.app.name
  private_endpoint_network_policies = "Disabled"
  address_prefixes                  = [var.subnet_app_cidr]
}

#Internal application gateway, private frontend
resource "azurerm_application_gateway" "appgw" {
  name                = var.appgw_name
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name

  sku {
    name     = var.appgw_sku # "Standard_v2" or "WAF_v2"
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
  sql_server_name  = "sql-${lower(var.app_name)}-${lower(var.environment)}-${lower(var.region_code)}"
  sql_db_name      = "sqldb-${lower(var.app_name)}-${lower(var.environment)}"
  sql_cmk_key_name = "cmk-sql-${lower(var.app_name)}-${lower(var.environment)}-${lower(var.region_code)}"
}

resource "azurerm_key_vault_key" "sql_cmk" {
  name         = local.sql_cmk_key_name
  key_vault_id = data.azurerm_key_vault.shared.id
  key_type     = "RSA"
  key_size     = 2048
  key_opts     = ["wrapKey", "unwrapKey"]
}

resource "azurerm_mssql_server" "sql" {
  name                = local.sql_server_name
  resource_group_name = azurerm_resource_group.app.name
  location            = azurerm_resource_group.app.location
  version             = "12.0"

  administrator_login          = var.sql_admin_login
  administrator_login_password = var.sql_admin_password

  identity {
    type = "SystemAssigned"
  }

  #fixes key bug
  lifecycle {
    ignore_changes = [
      transparent_data_encryption_key_vault_key_id
    ]
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


#app service vnet delegated subnet, for vnet integration
resource "azurerm_subnet" "appsvc_integration" {
  name                              = "snet-appsvc-int"
  resource_group_name               = azurerm_resource_group.app.name
  virtual_network_name              = azurerm_virtual_network.app.name
  private_endpoint_network_policies = "Enabled"
  address_prefixes                  = [var.appsvc_int_cidr]

  delegation {
    name = "delegation-appsvc"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

#linux app service plan
resource "azurerm_service_plan" "appsvc_plan" {
  count               = var.enable_app_service ? 1 : 0
  name                = "asp-${lower(var.app_name)}-${lower(var.environment)}-${lower(var.region_code)}"
  resource_group_name = azurerm_resource_group.app.name
  location            = azurerm_resource_group.app.location

  os_type  = "Linux"
  sku_name = "S1"

  tags = var.tags
}

# Linux Web App (Node) + Managed Identity
resource "azurerm_linux_web_app" "nodeapp" {
  count               = var.enable_app_service ? 1 : 0
  name                = var.appsvc_name
  resource_group_name = azurerm_resource_group.app.name
  location            = azurerm_resource_group.app.location
  service_plan_id     = azurerm_service_plan.appsvc_plan[count.index].id

  https_only = true

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on                         = true
    health_check_path                 = var.health_check_path
    health_check_eviction_time_in_min = 2

    application_stack {
      node_version = "20-lts"
    }

    # Optional, but helpful for “secure by default”
    minimum_tls_version = "1.2"
    ftps_state          = "Disabled"
  }

  app_settings = merge(
    { NODE_ENV                 = lower(var.environment)
      WEBSITE_RUN_FROM_PACKAGE = "1"
      PORT                     = "8080"

      # Optional: keeps deployments tidy / predictable
    SCM_DO_BUILD_DURING_DEPLOYMENT = "true" },

    #Flag to enable telemetry when flag is flipped (SKU provision is allowed)  
    var.enable_app_service ? {
      APPLICATIONINSIGHTS_CONNECTION_STRING = azurerm_application_insights.appins.connection_string
      APPINSIGHTS_CONNECTION_STRING         = azurerm_application_insights.appins.connection_string
    } : {}
  )

  tags = var.tags
}


#VNet integration to reach endpoints
resource "azurerm_app_service_virtual_network_swift_connection" "nodeapp_vnetint" {
  count          = var.enable_app_service ? 1 : 0
  app_service_id = azurerm_linux_web_app.nodeapp[count.index].id
  subnet_id      = azurerm_subnet.appsvc_integration.id
}


#Data source for application insights
data "azurerm_log_analytics_workspace" "shared" {
  name                = var.shared_law_name
  resource_group_name = var.shared_law_rg
}

resource "azurerm_application_insights" "appins" {
  name                = "appi-${lower(var.app_name)}-${lower(var.environment)}-${lower(var.region_code)}"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  application_type    = "web"
  workspace_id        = data.azurerm_log_analytics_workspace.shared.id

  tags = var.tags
}


#DNS zone lookups and VNet links
data "azurerm_private_dns_zone" "sql" {
  name                = "privatelink.database.windows.net"
  resource_group_name = var.shared_dns_rg
}

data "azurerm_private_dns_zone" "kv" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = var.shared_dns_rg
}

#link app to VNet of the dns zones
resource "azurerm_private_dns_zone_virtual_network_link" "sql_link" {
  name                  = "vnetlink-sql-${lower(var.environment)}-${lower(var.region_code)}"
  resource_group_name   = var.shared_dns_rg
  private_dns_zone_name = data.azurerm_private_dns_zone.sql.name
  virtual_network_id    = azurerm_virtual_network.app.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "kv_link" {
  name                  = "vnetlink-kv-${lower(var.environment)}-${lower(var.region_code)}"
  resource_group_name   = var.shared_dns_rg
  private_dns_zone_name = data.azurerm_private_dns_zone.kv.name
  virtual_network_id    = azurerm_virtual_network.app.id
}

#sql private endpoints
resource "azurerm_private_endpoint" "sql" {
  name                = "pe-sql-${lower(var.app_name)}-${lower(var.environment)}-${lower(var.region_code)}"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  subnet_id           = azurerm_subnet.app.id

  private_service_connection {
    name                           = "psc-sql-${lower(var.environment)}-${lower(var.region_code)}"
    private_connection_resource_id = azurerm_mssql_server.sql.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "pdzg-sql"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.sql.id]
  }

  tags = var.tags

  depends_on = [azurerm_private_dns_zone_virtual_network_link.sql_link]
}

#key vault private endpoint
resource "azurerm_private_endpoint" "kv" {
  name                = "pe-kv-${lower(var.app_name)}-${lower(var.environment)}-${lower(var.region_code)}"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  subnet_id           = azurerm_subnet.app.id

  private_service_connection {
    name                           = "psc-kv-${lower(var.environment)}-${lower(var.region_code)}"
    private_connection_resource_id = data.azurerm_key_vault.shared.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "pdzg-kv"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.kv.id]
  }

  tags = var.tags

  depends_on = [azurerm_private_dns_zone_virtual_network_link.kv_link]
}











