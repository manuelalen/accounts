{{ config(
    materialized='incremental',
    schema='bronze',
    unique_key='id',
    pre_hook=[
        "CREATE TEMP TABLE IF NOT EXISTS temp_raw_movimientos (id TEXT, monto NUMERIC, concepto TEXT, parsed_at TIMESTAMP);",
        "TRUNCATE temp_raw_movimientos;",
        -- Usamos una lógica de inserción segura desde el contenido que ya está en tu BD
        "INSERT INTO temp_raw_movimientos SELECT * FROM public.raw_objects WHERE ingestion_day = '{{ var('target_date') }}';"
    ]
) }}

SELECT 
    id,
    monto,
    concepto,
    parsed_at,
    '{{ var("target_date") }}' as ingestion_day
FROM temp_raw_movimientos