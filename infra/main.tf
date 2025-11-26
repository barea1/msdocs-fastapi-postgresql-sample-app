resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-rg"
  location = var.location
}

# 1. Base de Datos PostgreSQL (Configuración Económica para Estudiantes)
resource "azurerm_postgresql_flexible_server" "postgres" {
  name                   = "${var.prefix}-db-${random_string.suffix.result}"
  resource_group_name    = azurerm_resource_group.rg.name
  location               = azurerm_resource_group.rg.location
  version                = "13"
  administrator_login    = "psqladmin"
  administrator_password = var.db_password
  zone                   = "1"
  storage_mb             = 32768
  sku_name               = "B_Standard_B1ms" # SKU más económico (Burstable)
}

# Regla de Firewall: Permitir que otros servicios de Azure (como Container Apps) accedan a la BD
resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_azure" {
  name             = "AllowAzureServices"
  server_id        = azurerm_postgresql_flexible_server.postgres.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# Base de datos inicial
resource "azurerm_postgresql_flexible_server_database" "main_db" {
  name      = "todo_app"
  server_id = azurerm_postgresql_flexible_server.postgres.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

# 2. Entorno de Container Apps (Log Analytics + Environment)
resource "azurerm_log_analytics_workspace" "logs" {
  name                = "${var.prefix}-logs"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_container_app_environment" "env" {
  name                       = "${var.prefix}-env"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.logs.id
}

# 2.5. Azure Container Registry (ACR)
# Aquí guardaremos tus imágenes privadas de Docker
resource "azurerm_container_registry" "acr" {
  name                = "acr${var.prefix}${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic" # El más barato
  admin_enabled       = true    # Habilitamos usuario admin para facilitar la conexión
}

# 3. La Aplicación Container App
# Inicialmente desplegamos una imagen "Hello World" de Microsoft.
# Luego, GitHub Actions reemplazará esta imagen por tu "odyssey-app".
resource "azurerm_container_app" "app" {
  name                         = "${var.prefix}-app"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  # CRÍTICO: Conectamos la App con el Registro usando las credenciales de admin
  registry {
    server               = azurerm_container_registry.acr.login_server
    username             = azurerm_container_registry.acr.admin_username
    password_secret_name = "acr-password"
  }

  template {
    min_replicas = 0
    max_replicas = 1
    
    container {
      name   = "main-app"
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest" # Mantenemos Hello World por ahora
      cpu    = 0.25
      memory = "0.5Gi"
      
      env {
        name  = "DBHOST"
        value = azurerm_postgresql_flexible_server.postgres.fqdn
      }
      env {
        name  = "DBNAME"
        value = "todo_app"
      }
      env {
        name  = "DBUSER"
        value = "psqladmin"
      }
      env {
        name        = "DBPASS"
        secret_name = "db-pass"
      }
    }
  }

  secret {
    name  = "db-pass"
    value = var.db_password
  }
  
  # Guardamos la contraseña del ACR como secreto
  secret {
    name  = "acr-password"
    value = azurerm_container_registry.acr.admin_password
  }

  ingress {
    external_enabled = true 
    target_port      = 8000 # ¡CAMBIO! Tu app Python escucha en el 8000, no en el 80
    traffic_weight {
      percentage = 100
      latest_revision = true
    }
  }

  # TRUCO DE EXPERTO (Ignore Changes):
  # Le decimos a Terraform: "Si ves que la imagen ha cambiado en la nube (porque el pipeline la actualizó),
  # NO la restaures a 'hello-world'. Deja la que esté".
  lifecycle {
    ignore_changes = [
      template[0].container[0].image
    ]
  }
}

# Generador de sufijo aleatorio para que el nombre de la BD sea único mundialmente
resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

# Output: Nos devolverá la URL pública al terminar
output "app_url" {
  value = azurerm_container_app.app.latest_revision_fqdn
}

# Output: Información del ACR para el pipeline de GitHub Actions
output "acr_server" {
  value = azurerm_container_registry.acr.login_server
}