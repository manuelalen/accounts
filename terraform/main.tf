import {
  to = supabase_project.production_db
  id = "fzdpeakdudjfyvgrhrqq" # Tu Project Ref de la imagen
}

resource "supabase_project" "production_db" {
  organization_id   = var.organization_id
  name              = var.project_name
  region            = "eu-central-2"
  database_password = var.db_password

  lifecycle {
    ignore_changes = [database_password] 
  }
}

# Crear un bucket privado para almacenar tus datos crudos (Capas Raw / Data Lake)
resource "supabase_bucket" "raw_storage" {
  project_id    = supabase_project.production_db.id # Enlaza automáticamente con tu proyecto
  id            = "raw-data-lake"
  name          = "raw-data-lake"
  public        = false # Falso para que nadie pueda acceder desde internet sin permiso
  
  # Opcional: Restricciones de tamaño y formatos permitidos
  file_size_limit = 52428800 # 50 MB en bytes
  allowed_mime_types = ["text/csv", "application/json", "application/octet-stream"] 
}