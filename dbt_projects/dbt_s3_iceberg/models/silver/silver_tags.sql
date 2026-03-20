{{
    config(
        materialized='table',
        database='s3_tables',
        schema='silver'
    )
}}

with source as (
    select * from {{ source_parquet('bronze_s3', 'tags') }} limit 500
),

cleaned as (
    select
        "userId" as user_id,
        "movieId" as movie_id,
        lower(trim(tag)) as tag_normalized,
        tag as tag_original,
        timestamp as tag_timestamp,
        to_timestamp(try_cast(timestamp as double)) as tag_datetime,
        date_trunc('month', to_timestamp(try_cast(timestamp as double))) as tag_month,
        extract('year' from to_timestamp(try_cast(timestamp as double))) as year,
        -- Análise básica de sentimento
        case
            when lower(tag) like '%love%' or lower(tag) like '%great%' or lower(tag) like '%best%' 
                or lower(tag) like '%amazing%' or lower(tag) like '%excellent%' then 'Positivo'
            when lower(tag) like '%hate%' or lower(tag) like '%bad%' or lower(tag) like '%worst%' 
                or lower(tag) like '%terrible%' or lower(tag) like '%awful%' then 'Negativo'
            else 'Neutro'
        end as sentiment,
        -- Categorias de tags
        case
            when lower(tag) like '%funny%' or lower(tag) like '%comedy%' then 'Humor'
            when lower(tag) like '%action%' or lower(tag) like '%fight%' then 'Ação'
            when lower(tag) like '%romantic%' or lower(tag) like '%love%' then 'Romance'
            when lower(tag) like '%scary%' or lower(tag) like '%horror%' then 'Terror'
            when lower(tag) like '%twist%' or lower(tag) like '%plot%' then 'Enredo'
            else 'Outros'
        end as tag_category,
        length(tag) as tag_length,
        current_timestamp as processed_at
    from source
    where "userId" is not null
      and "movieId" is not null
      and tag is not null
      and trim(tag) != ''
      and try_cast(timestamp as double) is not null
)

select * from cleaned
