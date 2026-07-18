-- Crear la tabla de destino para la ingesta de CSVs
CREATE TABLE IF NOT EXISTS bronze.stg_movimientos (
    id TEXT,
    monto NUMERIC,
    concepto TEXT,
    parsed_at TIMESTAMPTZ DEFAULT NOW(),
    ingestion_day TEXT
);

-- Índice para buscar rápido por día de ingesta
CREATE INDEX IF NOT EXISTS idx_stg_movimientos_ingestion_day ON bronze.stg_movimientos (ingestion_day);

-- Función RPC para que la Edge Function pueda asegurar que la tabla existe
CREATE OR REPLACE FUNCTION public.ensure_bronze_table_exists()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = bronze, public
AS $$
BEGIN
    CREATE TABLE IF NOT EXISTS bronze.stg_movimientos (
        id TEXT,
        monto NUMERIC,
        concepto TEXT,
        parsed_at TIMESTAMPTZ DEFAULT NOW(),
        ingestion_day TEXT
    );
    CREATE INDEX IF NOT EXISTS idx_stg_movimientos_ingestion_day 
        ON bronze.stg_movimientos (ingestion_day);
END;
$$;
