-- 1. Crear las capas del Data Lakehouse como Esquemas aislados
CREATE SCHEMA IF NOT EXISTS bronze;
CREATE SCHEMA IF NOT EXISTS silver;
CREATE SCHEMA IF NOT EXISTS gold;

-- 2. Asegurar que el rol por defecto de dbt (postgres) tenga control total sobre ellos
GRANT ALL PRIVILEGES ON SCHEMA bronze TO postgres;
GRANT ALL PRIVILEGES ON SCHEMA silver TO postgres;
GRANT ALL PRIVILEGES ON SCHEMA gold TO postgres;