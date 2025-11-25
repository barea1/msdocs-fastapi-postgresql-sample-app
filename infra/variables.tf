variable "location" {
  default     = "spaincentral"
  description = "Región de Azure donde se desplegarán los recursos"
}

variable "prefix" {
  default     = "odyssey"
  description = "Prefijo común para nombrar los recursos"
}

variable "db_password" {
  description = "Contraseña segura para el administrador de PostgreSQL"
  type        = string
  sensitive   = true # Esto oculta la contraseña en los logs de Terraform
}