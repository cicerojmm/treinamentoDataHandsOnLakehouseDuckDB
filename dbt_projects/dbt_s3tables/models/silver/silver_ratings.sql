{{
    config(
        materialized='table',
        database='s3_tables',
        schema='silver'
    )
}}

with source as (
    select * from {{ source('bronze', 'ratings') }} limit 500
),

cleaned as (
    select
        user_id,
        movie_id,
        cast(rating as double) as rating,
        timestamp as rating_timestamp,
        -- Converter timestamp Unix para datetime
        to_timestamp(cast(timestamp as double)) as rating_datetime,
        -- Extrair componentes de data
        date_trunc('day', to_timestamp(cast(timestamp as double))) as rating_date,
        date_trunc('month', to_timestamp(cast(timestamp as double))) as rating_month,
        date_trunc('year', to_timestamp(cast(timestamp as double))) as rating_year,
        extract('year' from to_timestamp(cast(timestamp as double))) as year,
        extract('month' from to_timestamp(cast(timestamp as double))) as month,
        extract('dow' from to_timestamp(cast(timestamp as double))) as day_of_week,
        extract('hour' from to_timestamp(cast(timestamp as double))) as hour_of_day,
        -- Classificação da avaliação
        case
            when cast(rating as double) >= 4.5 then 'Excelente'
            when cast(rating as double) >= 3.5 then 'Bom'
            when cast(rating as double) >= 2.5 then 'Regular'
            else 'Ruim'
        end as rating_category,
        current_timestamp as processed_at
    from source
    where user_id is not null
      and movie_id is not null
      and cast(rating as double) between 0.5 and 5.0
)

select * from cleaned
