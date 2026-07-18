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
