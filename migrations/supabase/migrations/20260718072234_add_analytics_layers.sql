-- Creación de las capas físicas del Data Lakehouse
CREATE SCHEMA IF NOT EXISTS bronze;
CREATE SCHEMA IF NOT EXISTS silver;
CREATE SCHEMA IF NOT EXISTS gold;

-- Conceder permisos de administración al rol por defecto de dbt
GRANT ALL PRIVILEGES ON SCHEMA bronze TO postgres;
GRANT ALL PRIVILEGES ON SCHEMA silver TO postgres;
GRANT ALL PRIVILEGES ON SCHEMA gold TO postgres;


INSERT INTO storage.buckets (id, name, public)
VALUES ('raw-data-lake', 'raw-data-lake', false)
ON CONFLICT (id) DO NOTHING;


UPDATE storage.buckets
SET allowed_mime_types = '{text/csv, application/json, application/octet-stream}'
WHERE id = 'raw-data-lake';