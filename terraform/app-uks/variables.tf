#Parameterised variables for the entire stack so can be redeployed as passive server
variable "location"     { type = string }
variable "environment"  { type = string }
variable "app_name"     { type = string }
variable "region_code"  { type = string }
variable "tags"         { type = map(string) }

#vnet and app gateway vars
variable "app_vnet_name"        { type = string }
variable "app_vnet_cidr"        { type = list(string) }

variable "subnet_appgw_cidr"    { type = string } # App Gateway subnet
variable "subnet_app_cidr"      { type = string } # App workload subnet (PEs, integration)

variable "appgw_name"           { type = string }
variable "appgw_sku"            { type = string } # "Standard_v2" or "WAF_v2"
variable "appgw_capacity"       { type = number }

variable "appgw_private_ip"     { type = string } # static IP inside subnet_appgw_cidr

#key for cert for app gateway
variable "shared_kv_name" { type = string }
variable "shared_kv_rg"   { type = string }

variable "appgw_cert_name" { type = string } # name of the cert in Key Vault

#sql variables
variable "sql_admin_login" { type = string }

variable "sql_admin_password" {
  type      = string
  sensitive = true
}

