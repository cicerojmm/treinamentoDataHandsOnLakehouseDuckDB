{{
    config(
        materialized='table',
        database='s3_tables',
        schema='gold'
    )
}}

with movies as (
    select * from {{ ref('silver_movies') }}
),

ratings as (
    select * from {{ ref('silver_ratings') }}
),

movie_stats as (
    select
        m.movie_id,
        m.title_clean,
        m.release_year,
        m.genres,
        count(r.rating) as rating_count,
        round(avg(r.rating), 2) as avg_rating
    from movies m
    left join ratings r on m.movie_id = r.movie_id
    group by m.movie_id, m.title_clean, m.release_year, m.genres
    having count(r.rating) >= 10
),

-- Calcular similaridade baseada em gêneros compartilhados
movie_similarity as (
    select
        m1.movie_id,
        m1.title_clean as movie_title,
        m2.movie_id as similar_movie_id,
        m2.title_clean as similar_movie_title,
        m2.release_year as similar_movie_year,
        m2.avg_rating as similar_movie_rating,
        m2.rating_count as similar_movie_ratings_count,
        
        -- Contar gêneros em comum
        array_length(list_intersect(
            string_split(m1.genres, '|'),
            string_split(m2.genres, '|')
        )) as common_genres,
        
        -- Jaccard similarity
        round(
            cast(array_length(list_intersect(
                string_split(m1.genres, '|'),
                string_split(m2.genres, '|')
            )) as double) /
            cast(array_length(list_distinct(list_concat(
                string_split(m1.genres, '|'),
                string_split(m2.genres, '|')
            ))) as double),
            3
        ) as genre_similarity,
        
        abs(m1.release_year - m2.release_year) as year_diff,
        
        -- Score de recomendação
        round(
            (cast(array_length(list_intersect(
                string_split(m1.genres, '|'),
                string_split(m2.genres, '|')
            )) as double) /
             cast(array_length(list_distinct(list_concat(
                string_split(m1.genres, '|'),
                string_split(m2.genres, '|')
            ))) as double) * 0.6) +
            ((5.0 - least(abs(m1.release_year - m2.release_year) / 10.0, 5.0)) / 5.0 * 0.2) +
            (m2.avg_rating / 5.0 * 0.2),
            3
        ) as recommendation_score
        
    from movie_stats m1
    cross join movie_stats m2
    where m1.movie_id != m2.movie_id
      and array_length(list_intersect(
          string_split(m1.genres, '|'),
          string_split(m2.genres, '|')
      )) > 0
),

ranked_recommendations as (
    select
        *,
        row_number() over (partition by movie_id order by recommendation_score desc, similar_movie_ratings_count desc) as recommendation_rank
    from movie_similarity
    where genre_similarity >= 0.3
)

select
    movie_id,
    movie_title,
    similar_movie_id,
    similar_movie_title,
    similar_movie_year,
    similar_movie_rating,
    similar_movie_ratings_count,
    common_genres,
    genre_similarity,
    year_diff,
    recommendation_score,
    recommendation_rank,
    current_timestamp as processed_at
from ranked_recommendations
where recommendation_rank <= 10
order by movie_id, recommendation_rank
