{{ config(
    materialized='incremental',
    schema='bronze',
    unique_key='id'
) }}

WITH source_data AS (
    -- Aquí haces referencia a tu función externa o tabla externa que lee del storage
    SELECT * 
    FROM {{ source('supabase_storage', 'raw_objects') }}
    -- Si tu motor lee directamente el bucket como un data lake parametrizado:
    WHERE date_partition = '{{ var("target_date", run_started_at.strftime("%Y-%m-%d")) }}'
)

SELECT 
    id,
    monto,
    concepto,
    parsed_at,
    '{{ var("target_date") }}' as ingestion_day
FROM source_data