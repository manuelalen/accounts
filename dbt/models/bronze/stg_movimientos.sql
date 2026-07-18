{{ config(
    materialized='incremental',
    schema='bronze',
    unique_key='id'
) }}


WITH raw_data AS (
    SELECT 
        (metadata->>'id') as id,
        (metadata->>'monto')::numeric as monto,
        (metadata->>'concepto') as concepto,
        (metadata->>'parsed_at')::timestamp as parsed_at
    FROM storage.objects
    WHERE bucket_id = 'raw-data-lake'
    AND name LIKE '{{ var("target_date") | replace("-", "/") }}%'
)

SELECT 
    id,
    monto,
    concepto,
    parsed_at,
    '{{ var("target_date") }}' as ingestion_day
FROM raw_data
WHERE id IS NOT NULL -- Filtramos los registros vacíos o mal parseados