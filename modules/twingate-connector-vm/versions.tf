terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
    twingate = {
      source  = "Twingate/twingate"
      version = ">= 3.0"
    }
  }
}
