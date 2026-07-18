{{ config(
    materialized='incremental',
    schema='bronze',
    unique_key='id'
) }}


SELECT 
    (metadata->>'id') as id,
    (metadata->>'monto')::numeric as monto,
    (metadata->>'concepto') as concepto,
    created_at as parsed_at,
    '{{ var("target_date") }}' as ingestion_day
FROM storage.objects
WHERE bucket_id = 'raw-data-lake'
AND name LIKE '{{ var("target_date") | replace("-", "/") }}%'

{% if is_incremental() %}
  AND created_at > (SELECT MAX(parsed_at) FROM {{ this }})
{% endif %}