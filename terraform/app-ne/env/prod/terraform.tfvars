location    = "northeurope"
environment = "prod"
app_name    = "nodeapp"
region_code = "ne"

tags = {
  Application        = "NodeApp"
  Criticality        = "High"
  DataClassification = "Confidential"
  Environment        = "Prod"
  ManagedBy          = "Terraform"
  Owner              = "Development"
  RegionRole         = "Active"
}

#vars for vnet, subnet, app gateway
app_vnet_name = "vnet-app-nodeapp-prod-ne"
app_vnet_cidr = ["10.10.0.0/16"]

subnet_appgw_cidr = "10.10.1.0/24"
subnet_app_cidr   = "10.10.2.0/24"

appgw_name     = "agw-nodeapp-prod-ne"
appgw_sku      = "Standard_v2" # or "Standard_v2" to reduce scope/cost
appgw_capacity = 1

appgw_private_ip = "10.10.1.10"

#shared keyvault and appgw cert vars
shared_kv_name  = "kv-shared-hub-prod-ne01"
shared_kv_rg    = "rg-shared-hub-prod"
appgw_cert_name = "cert-appgw-nodeapp-prod-ne"

#sql vars
sql_admin_login = "sqladminuser"

#appsvc vars
#appsvc_plan_sku  = "P0v4"
appsvc_name        = "app-nodeapp-prod-ne01"
appsvc_int_cidr    = "10.10.3.0/24"
health_check_path  = "/health"
enable_app_service = true

#app insights vars
shared_law_name = "law-shared-hub-prod-ne"
shared_law_rg   = "rg-shared-hub-prod"

#private endpoint vars
shared_dns_rg = "rg-shared-hub-prod"

#subscription id var
subscription_id = "26759326-d758-4f5a-896a-324b4275eae2"



