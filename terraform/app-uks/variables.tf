#Parameterised variables for the entire stack so can be redeployed as passive server
variable "location"     { type = string }
variable "environment"  { type = string }
variable "app_name"     { type = string }
variable "region_code"  { type = string }
variable "tags"         { type = map(string) }