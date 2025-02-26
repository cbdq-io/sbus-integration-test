terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.14.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.7.1"
    }
  }

  required_version = "~> 1.10"
}

provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
}
