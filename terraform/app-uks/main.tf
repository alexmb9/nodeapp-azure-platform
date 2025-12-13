#resource group for 
resource "azurerm_resource_group" "app" {
  name     = "rg-${lower(var.app_name)}-${lower(var.environment)}-${lower(var.region_code)}"
  location = var.location
  tags     = var.tags
}