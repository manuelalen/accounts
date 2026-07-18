{{ config(
    materialized='incremental',
    schema='bronze',
    unique_key='id'
) }}

WITH raw_file AS (
    SELECT 
        (regexp_split_to_array(line, ','))[1] as id,
        (regexp_split_to_array(line, ','))[2]::numeric as monto,
        (regexp_split_to_array(line, ','))[3] as concepto,
        (regexp_split_to_array(line, ','))[4]::timestamp as parsed_at
    FROM (
        SELECT unnest(string_to_array(convert_from(storage.download('raw-data-lake', '{{ var("target_date") | replace("-", "/") }}/movimientos.csv'), 'UTF8'), E'\n')) as line
    ) as t
    WHERE line NOT LIKE 'id,%' -- Ignora header
)

SELECT 
    id, monto, concepto, parsed_at,
    '{{ var("target_date") }}' as ingestion_day
FROM raw_file
WHERE id IS NOT NULL

{% if is_incremental() %}
  AND parsed_at > (SELECT MAX(parsed_at) FROM {{ this }})
{% endif %}