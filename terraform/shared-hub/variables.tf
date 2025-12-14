# Core variables
variable "location" { type = string }
variable "environment" { type = string }
variable "app_name" { type = string }
variable "region_code" { type = string }
variable "tags" { type = map(string) }

# Hub VNet and Azure Firewall variables
variable "hub_vnet_name" { type = string }
variable "hub_vnet_cidr" { type = list(string) }
variable "fw_subnet_cidr" { type = string }
variable "fw_name" { type = string }
variable "fw_public_ip_name" { type = string }

# App VNet and subnet variables
variable "app_vnet_name" { type = string }
variable "app_vnet_cidr" { type = list(string) }
variable "subnet_appgw_cidr" { type = string }
variable "subnet_app_cidr" { type = string }
variable "appsvc_int_cidr" { type = string }

# Application Gateway variables
variable "appgw_name" { type = string }
variable "appgw_sku" { type = string }
variable "appgw_capacity" { type = number }
variable "appgw_private_ip" { type = string }

# Shared resources references
variable "shared_kv_name" { type = string }
variable "shared_kv_rg" { type = string }
variable "shared_law_name" { type = string }
variable "shared_law_rg" { type = string }
variable "shared_dns_rg" { type = string }

# Log Analytics variables
variable "log_analytics_name" { type = string }
variable "log_analytics_sku" { type = string }
variable "log_retention_days" { type = number }

# Key Vault variables
variable "key_vault_name" { type = string }

# Certificate variables
variable "appgw_cert_name" { type = string }