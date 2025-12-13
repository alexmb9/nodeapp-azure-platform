#All resource vars
variable "location" { type = string }
variable "environment" { type = string }
variable "tags" { type = map(string) }

#Hub Vnet and Azure Firewall vars
variable "hub_vnet_name" { type = string }
variable "hub_vnet_cidr" { type = list(string) }     # e.g. ["10.0.0.0/16"]
variable "fw_subnet_cidr" { type = string }          # e.g. "10.0.1.0/26"
variable "fw_name" { type = string }
variable "fw_public_ip_name" { type = string }

#Log analytics vars
variable "log_analytics_name" { type = string }
variable "log_analytics_sku"  { type = string }   # e.g. "PerGB2018"
variable "log_retention_days" { type = number }   # e.g. 30