variable "supabase_access_token" {
  type        = string
  description = "Token de acceso personal de Supabase (generado en Account Settings > Access Tokens)"
  sensitive   = true
}

variable "organization_id" {
  type        = string
  description = "ID de tu organización en Supabase"
}

variable "db_password" {
  type        = string
  description = "Contraseña maestra de Postgres para la base de datos"
  sensitive   = true
}

variable "project_name" {
  type        = string
  default     = "data-platform-production"
  description = "Nombre identificativo del proyecto"
}