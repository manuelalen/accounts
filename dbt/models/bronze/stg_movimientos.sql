{{ config(
    materialized='incremental',
    schema='bronze',
    unique_key='id'
) }}


SELECT 
    id,
    monto,
    concepto,
    parsed_at,
    '{{ var("target_date") }}' as ingestion_day
FROM bronze.movimientos_raw -- CAMBIA ESTO POR EL NOMBRE DE TU TABLA REAL DE DATOS
WHERE ingestion_day = '{{ var("target_date") }}'