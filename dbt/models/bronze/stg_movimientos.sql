{{ config(
    materialized='incremental',
    schema='bronze',
    unique_key='id',
    pre_hook=[
        "CREATE TEMP TABLE IF NOT EXISTS raw_movimientos AS SELECT * FROM storage.objects WHERE bucket_id = 'raw-data-lake' AND name LIKE '{{ var('target_date') | replace('-', '/') }}%'"
    ]
) }}

WITH source_data AS (
    -- dbt procesa directamente el contenido del storage mediante la lógica SQL
    -- que se ejecuta en el pre-hook sobre la tabla temporal
    SELECT 
        (metadata->>'id')::text as id,
        (metadata->>'monto')::numeric as monto,
        (metadata->>'concepto')::text as concepto,
        created_at as parsed_at
    FROM raw_movimientos
)

SELECT 
    id,
    monto,
    concepto,
    parsed_at,
    '{{ var("target_date") }}' as ingestion_day
FROM source_data

{% if is_incremental() %}
  WHERE parsed_at > (SELECT MAX(parsed_at) FROM {{ this }})
{% endif %}