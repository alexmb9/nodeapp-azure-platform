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
  sku_tier            = "Standard" # keep cost down; can change later
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

#azure sql private DNS zone
resource "azurerm_private_dns_zone" "sql" {
  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.shared.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "sql_hub_link" {
  name                  = "sql-hub-link"
  resource_group_name   = azurerm_resource_group.shared.name
  private_dns_zone_name = azurerm_private_dns_zone.sql.name
  virtual_network_id    = azurerm_virtual_network.hub.id
}

#key vault private DNS zone
resource "azurerm_private_dns_zone" "kv" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.shared.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "kv_hub_link" {
  name                  = "kv-hub-link"
  resource_group_name   = azurerm_resource_group.shared.name
  private_dns_zone_name = azurerm_private_dns_zone.kv.name
  virtual_network_id    = azurerm_virtual_network.hub.id
}

#app service private dns
resource "azurerm_private_dns_zone" "appsvc" {
  name                = "privatelink.azurewebsites.net"
  resource_group_name = azurerm_resource_group.shared.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "appsvc_hub_link" {
  name                  = "appsvc-hub-link"
  resource_group_name   = azurerm_resource_group.shared.name
  private_dns_zone_name = azurerm_private_dns_zone.appsvc.name
  virtual_network_id    = azurerm_virtual_network.hub.id
}

#key vault resource
data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "shared" {
  name                = var.key_vault_name
  location            = azurerm_resource_group.shared.location
  resource_group_name = azurerm_resource_group.shared.name
  tenant_id           = data.azurerm_client_config.current.tenant_id

  sku_name                  = "standard"
  enable_rbac_authorization = true

  soft_delete_retention_days = 90
  purge_protection_enabled   = true

  # We'll disable this once we add a Private Endpoint in the app stacks
  public_network_access_enabled = true

  tags = var.tags
}

# give user current admin rights of the shared platform
resource "azurerm_role_assignment" "kv_platform_admin" {
  scope                = azurerm_key_vault.shared.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id

  lifecycle {
    ignore_changes        = [name]
    create_before_destroy = false
  }
}

#diagnostics resources for log analytics workspace
resource "azurerm_monitor_diagnostic_setting" "firewall_diag" {
  name                       = "diag-firewall"
  target_resource_id         = azurerm_firewall.fw.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  enabled_log { category = "AzureFirewallApplicationRule" }
  enabled_log { category = "AzureFirewallNetworkRule" }
  enabled_log { category = "AzureFirewallDnsProxy" }

  metric { category = "AllMetrics" }
}

resource "azurerm_monitor_diagnostic_setting" "kv_diag" {
  name                       = "diag-keyvault"
  target_resource_id         = azurerm_key_vault.shared.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  enabled_log { category = "AuditEvent" }
  metric { category = "AllMetrics" }
}
