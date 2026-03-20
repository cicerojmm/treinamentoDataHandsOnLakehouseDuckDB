{{
    config(
        materialized='table',
        database='s3_tables',
        schema='silver'
    )
}}

with source as (
    select * from {{ source('bronze', 'links') }} limit 500
),

cleaned as (
    select
        movie_id,
        imdb_id,
        tmdb_id,
        -- Construir URLs completas
        'https://www.imdb.com/title/tt' || lpad(cast(imdb_id as varchar), 7, '0') as imdb_url,
        'https://www.themoviedb.org/movie/' || cast(tmdb_id as varchar) as tmdb_url,
        current_timestamp as processed_at
    from source
    where movie_id is not null
)

select * from cleaned
