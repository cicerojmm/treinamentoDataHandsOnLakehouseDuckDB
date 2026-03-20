{{
    config(
        materialized='table',
        database='s3_tables',
        schema='silver'
    )
}}

with source as (
    select * from {{ source_parquet('bronze_s3', 'links') }} limit 500
),

cleaned as (
    select
        "movieId" as movie_id,
        "imdbId" as imdb_id,
        "tmdbId" as tmdb_id,
        -- Construir URLs completas
        'https://www.imdb.com/title/tt' || lpad(cast("imdbId" as varchar), 7, '0') as imdb_url,
        'https://www.themoviedb.org/movie/' || cast("tmdbId" as varchar) as tmdb_url,
        current_timestamp as processed_at
    from source
    where "movieId" is not null
)

select * from cleaned
