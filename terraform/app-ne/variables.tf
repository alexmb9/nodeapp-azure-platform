#Parameterised variables for the entire stack so can be redeployed as passive server
variable "location" { type = string }
variable "environment" { type = string }
variable "app_name" { type = string }
variable "region_code" { type = string }
variable "tags" { type = map(string) }

#vnet and app gateway vars
variable "app_vnet_name" { type = string }
variable "app_vnet_cidr" { type = list(string) }

variable "subnet_appgw_cidr" { type = string } # App Gateway subnet
variable "subnet_app_cidr" { type = string }   # App workload subnet (PEs, integration)

variable "appgw_name" { type = string }
variable "appgw_sku" { type = string } # "Standard_v2" or "WAF_v2"
variable "appgw_capacity" { type = number }

variable "appgw_private_ip" { type = string } # static IP inside subnet_appgw_cidr

#key for cert for app gateway
variable "shared_kv_name" { type = string }
variable "shared_kv_rg" { type = string }

variable "appgw_cert_name" { type = string } # name of the cert in Key Vault

#sql variables
variable "sql_admin_login" { type = string }

variable "sql_admin_password" {
  type      = string
  sensitive = true
}

#app-svc variables
variable "appsvc_name" { type = string }       # keep unique per env/region
variable "appsvc_int_cidr" { type = string }   # delegated subnet for VNet integration
variable "health_check_path" { type = string } # e.g. "/health"

#feature flag for app service (as SKU v3 are unavailable)
variable "enable_app_service" {
  type    = bool
  default = false
}

#application insights variables
variable "shared_law_name" { type = string }
variable "shared_law_rg" { type = string }

#private dns zone vars
variable "shared_dns_rg" { type = string } # rg where Private DNS zones live (shared-hub)

##subscription change for v4
variable "subscription_id" {
  type        = string
  description = "Azure subscription ID"
}

#sql server password variable
variable "sql_admin_password" {
  type        = string
  sensitive   = true
  description = "SQL Server administrator password"
}