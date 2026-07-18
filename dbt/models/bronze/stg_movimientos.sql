{{ config(
    materialized='incremental',
    unique_key='id'
) }}

WITH raw_data AS (
    -- Esta consulta accede al catálogo de almacenamiento de Supabase
    -- sin depender de funciones externas que den error de permisos.
    SELECT 
        (metadata->>'id') as id,
        (metadata->>'monto')::numeric as monto,
        (metadata->>'concepto') as concepto,
        created_at as parsed_at
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
WHERE id IS NOT NULL

{% if is_incremental() %}
  AND parsed_at > (SELECT MAX(parsed_at) FROM {{ this }})
{% endif %}