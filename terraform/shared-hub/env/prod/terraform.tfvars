location    = "northeurope"
environment = "Prod"
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

# App VNet / subnets / AppGW (NON-overlapping CIDRs)
app_vnet_name     = "vnet-app-nodeapp-prod-ne"
app_vnet_cidr     = ["10.21.0.0/16"]

subnet_appgw_cidr = "10.21.1.0/24"
subnet_app_cidr   = "10.21.2.0/24"
appsvc_int_cidr   = "10.21.3.0/24"

appgw_name        = "agw-nodeapp-prod-ne"
appgw_sku         = "Standard_v2"
appgw_capacity    = 1
appgw_private_ip  = "10.21.1.10"

# Shared references (point to existing North europe shared-hub)
shared_kv_name  = "kv-shared-hub-prod-ne01"
shared_kv_rg    = "rg-shared-hub-prod"

shared_law_name = "law-shared-hub-prod-ne"
shared_law_rg   = "rg-shared-hub-prod"

shared_dns_rg    = "rg-shared-hub-prod"

# AppGW cert name stored in shared KV (unique per region)
appgw_cert_name  = "cert-appgw-nodeapp-prod-ne"

# Add these to your env/prod/terraform.tfvars:

hub_vnet_name        = "vnet-hub-prod-ne"
hub_vnet_cidr        = ["10.20.0.0/16"]
fw_subnet_cidr       = "10.20.1.0/26"
fw_name              = "afw-hub-prod-ne"
fw_public_ip_name    = "pip-afw-hub-prod-ne"

log_analytics_name   = "law-shared-hub-prod-ne"
log_analytics_sku    = "PerGB2018"
log_retention_days   = 30

key_vault_name       = "kv-shared-hub-prod-ne01"
