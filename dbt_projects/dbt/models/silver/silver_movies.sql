{{
  config(
    materialized='table',
    database='s3_tables',
    schema='silver',
  )
}}

with source as (
    select * from {{ source('bronze', 'movies') }} limit 500
),

cleaned as (
    select
        movie_id,
        trim(title) as title,
        -- Extrair ano do título (formato: "Movie Title (YYYY)")
        try_cast(regexp_extract(title, '\((\d{4})\)$', 1) as integer) as release_year,
        -- Remover ano do título
        trim(regexp_replace(title, '\s*\(\d{4}\)$', '')) as title_clean,
        genres,
        -- Contar quantidade de gêneros
        array_length(string_split(genres, '|')) as genres_count,
        -- Flags para gêneros principais
        contains(genres, 'Action') as is_action,
        contains(genres, 'Comedy') as is_comedy,
        contains(genres, 'Drama') as is_drama,
        contains(genres, 'Thriller') as is_thriller,
        contains(genres, 'Romance') as is_romance,
        contains(genres, 'Horror') as is_horror,
        contains(genres, 'Sci-Fi') as is_scifi,
        contains(genres, 'Animation') as is_animation,
        contains(genres, 'Documentary') as is_documentary,
        -- Década do filme
        floor(try_cast(regexp_extract(title, '\((\d{4})\)$', 1) as integer) / 10) * 10 as decade,
        current_timestamp as processed_at
    from source
    where movie_id is not null
)

select * from cleaned
