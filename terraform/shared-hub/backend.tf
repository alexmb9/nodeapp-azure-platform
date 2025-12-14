terraform {
  backend "azurerm" {
    resource_group_name  = "rg-shared-hub-prod"
    storage_account_name = "sttfstatesharedambprod"
    container_name       = "tfstate"
    key                  = "prod/shared-hub.tfstate"
  }
}