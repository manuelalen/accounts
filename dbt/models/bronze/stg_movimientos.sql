{{ config(
    materialized='incremental',
    schema='bronze',
    unique_key='id'
) }}


WITH raw_data AS (
    SELECT 
        (regexp_split_to_array(line, ','))[1] as id,
        (regexp_split_to_array(line, ','))[2]::numeric as monto,
        (regexp_split_to_array(line, ','))[3] as concepto,
        (regexp_split_to_array(line, ','))[4]::timestamp as parsed_at
    FROM (
        -- Leemos el archivo mediante el path directo al sistema de archivos de Supabase
        SELECT unnest(string_to_array(convert_from(pg_read_binary_file('/var/lib/postgresql/data/storage/raw-data-lake/' || '{{ var("target_date") | replace("-", "/") }}' || '/movimientos.csv'), 'UTF8'), E'\n')) as line
    ) as t
    WHERE line NOT LIKE 'id,%' 
)

SELECT * FROM raw_data WHERE id IS NOT NULL

{% if is_incremental() %}
  AND parsed_at > (SELECT MAX(parsed_at) FROM {{ this }})
{% endif %}