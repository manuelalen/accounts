{{ config(
    materialized='incremental',
    schema='bronze',
    unique_key='id'
) }}

WITH raw_file AS (
    SELECT 
        regexp_split_to_array(line, ',') as columns
    FROM (
        SELECT unnest(string_to_array(convert_from(storage.download('raw-data-lake', '{{ var("target_date") | replace("-", "/") }}/movimientos.csv'), 'UTF8'), E'\n')) as line
    ) as t
    WHERE line NOT LIKE 'id,%' -- Saltamos el header
)

SELECT 
    columns[1]::text as id,
    columns[2]::numeric as monto,
    columns[3]::text as concepto,
    columns[4]::timestamp as parsed_at,
    '{{ var("target_date") }}' as ingestion_day
FROM raw_file

{% if is_incremental() %}
  WHERE parsed_at > (SELECT MAX(parsed_at) FROM {{ this }})
{% endif %}