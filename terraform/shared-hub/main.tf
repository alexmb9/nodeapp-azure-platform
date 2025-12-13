resource "azurerm_resource_group" "shared" {
  name     = "rg-shared-hub-prod"
  location = var.location
  tags     = var.tags
}