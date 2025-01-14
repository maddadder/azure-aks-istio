#############################
## Application - Variables ##
#############################

# app name 
variable "app_name" {
  type        = string
  description = "This variable defines the application name used to build resources"
}

# company name 
variable "company" {
  type        = string
  description = "This variable defines the company name used to build resources"
}

# company prefix 
variable "prefix" {
  type        = string
  description = "This variable defines the company name prefix used to build resources"
}

# azure region
variable "location" {
  type        = string
  description = "Azure region where the resource group will be created"
}

# azure region
variable "region" {
  type        = string
  description = "Azure region code where the resource group will be created"
}

# application or company environment
variable "environment" {
  type        = string
  description = "This variable defines the environment to be built"
}

variable "route53-secret" {
  type        = string
  description = "The route53 secret. This variable should be stored in terraform.tfvars"
}

variable "vpn_instance_count" {
  default = 1
}

variable "aks_instance_count" {
  default = 1
}
