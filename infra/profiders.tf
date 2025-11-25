terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  # Configuración del Backend Remoto (Aquí se guardará el estado)
  backend "azurerm" {
    resource_group_name  = "rg-odyssey-tfstate"
    storage_account_name = "odysseytfstate2024"
    container_name       = "tfstate"
    key                  = "odyssey.tfstate"
  }
}

provider "azurerm" {
  features {}
}