-- {{
--     config(
--         -- MATERIALIZAÇÃO
--         materialized='incremental',      -- table, view, incremental, ephemeral
--         incremental_strategy='merge',    -- merge, append, delete+insert

--         -- CHAVES
--         unique_key='id',                 -- string ou lista ['id', 'data']
--         merge_update_columns=['valor', 'updated_at'],  -- só atualiza essas colunas

--         -- LOCALIZAÇÃO
--         database='lakehouse',            -- nome do ATTACH
--         schema='silver',                 -- namespace/schema

--         -- FORMATO
--         table_format='iceberg',          -- iceberg, delta, hudi
--         file_format='parquet',           -- parquet, orc

--         -- PARTIÇÃO
--         partition_by=['ano', 'mes'],     -- lista de colunas

--         -- ICEBERG ESPECÍFICO
--         table_properties={
--             'write.format.default':             'parquet',
--             'write.parquet.compression-codec':  'snappy',
--             'write.metadata.compression-codec': 'gzip',
--             'write.target-file-size-bytes':     '134217728',  -- 128MB
--         },

--         -- COMPORTAMENTO
--         full_refresh=false,              -- ignora --full-refresh global
--         on_schema_change='sync_all_columns',  -- fail, ignore, append_new_columns, sync_all_columns
--         grants={'select': ['metabase']}  -- permissões
--     )
-- }}



{{
  config(
    materialized='table',
    database='s3_tables',
    schema='silver',
  )
}}

with source as (
    select * from {{ source_parquet('bronze_s3', 'movies') }} limit 500
),

cleaned as (
    select
        "movieId" as movie_id,
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
    where "movieId" is not null
)

select * from cleaned
