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
FROM public.read_csv_from_storage('raw-data-lake', '{{ var("target_date", "2026-07-18") | replace("-", "/") }}/movimientos.csv')

{% if is_incremental() %}
  -- Esto evita duplicados aunque el mismo archivo se procese dos veces
  WHERE parsed_at > (SELECT MAX(parsed_at) FROM {{ this }})
{% endif %}