output "project_id" {
  value       = supabase_project.production_db.id
  description = "ID del proyecto generado por Supabase"
}

output "db_host" {
  value       = "db.${supabase_project.production_db.id}.supabase.co"
  description = "DNS endpoint para la conexión directa o pooler de dbt"
}