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

tags as (
    select * from {{ ref('silver_tags') }}
),

genre_exploded as (
    select
        m.movie_id,
        m.title_clean,
        m.release_year,
        m.decade,
        unnest(string_split(m.genres, '|')) as genre
    from movies m
    where m.genres != '(no genres listed)'
),

genre_metrics as (
    select
        ge.genre,

        cast(count(distinct ge.movie_id) as bigint)         as total_movies,
        cast(count(distinct ge.decade) as bigint)           as decades_active,
        min(ge.release_year)                                as first_movie_year,
        max(ge.release_year)                                as last_movie_year,

        cast(count(r.rating) as bigint)                     as total_ratings,
        cast(count(distinct r.user_id) as bigint)           as total_users,
        round(avg(r.rating), 2)                             as avg_rating,
        round(stddev(r.rating), 2)                          as stddev_rating,
        approx_quantile(r.rating, 0.50)                     as median_rating,

        cast(sum(case when r.rating >= 4.5 then 1 else 0 end) as bigint)                          as excellent_ratings,
        cast(sum(case when r.rating >= 3.5 and r.rating < 4.5 then 1 else 0 end) as bigint)       as good_ratings,
        cast(sum(case when r.rating >= 2.5 and r.rating < 3.5 then 1 else 0 end) as bigint)       as average_ratings,
        cast(sum(case when r.rating < 2.5 then 1 else 0 end) as bigint)                           as poor_ratings,

        round(100.0 * cast(sum(case when r.rating >= 4.0 then 1 else 0 end) as double) / nullif(cast(count(r.rating) as double), 0), 2) as pct_positive,

        cast(count(distinct t.tag_normalized) as bigint)    as unique_tags,
        cast(sum(case when t.sentiment = 'Positivo' then 1 else 0 end) as bigint)  as positive_tags,
        cast(sum(case when t.sentiment = 'Negativo' then 1 else 0 end) as bigint)  as negative_tags,

        round(cast(count(r.rating) as double) / nullif(cast(count(distinct ge.movie_id) as double), 0), 2) as avg_ratings_per_movie,
        round(cast(count(t.tag_normalized) as double) / nullif(cast(count(distinct ge.movie_id) as double), 0), 2) as avg_tags_per_movie,

        cast(sum(case when ge.decade = 1990 then 1 else 0 end) as bigint) as movies_1990s,
        cast(sum(case when ge.decade = 2000 then 1 else 0 end) as bigint) as movies_2000s,
        cast(sum(case when ge.decade = 2010 then 1 else 0 end) as bigint) as movies_2010s

    from genre_exploded ge
    left join ratings r on ge.movie_id = r.movie_id
    left join tags t on ge.movie_id = t.movie_id
    group by ge.genre
),

with_rankings as (
    select
        *,
        row_number() over (order by total_movies desc)           as rank_by_movies,
        row_number() over (order by total_ratings desc)          as rank_by_ratings,
        row_number() over (order by avg_rating desc)             as rank_by_quality,
        row_number() over (order by avg_ratings_per_movie desc)  as rank_by_engagement,

        case
            when avg_rating >= 4.0 then 'Alta Qualidade'
            when avg_rating >= 3.5 then 'Boa Qualidade'
            when avg_rating >= 3.0 then 'Qualidade Média'
            else 'Baixa Qualidade'
        end as quality_tier,

        case
            when total_ratings >= 50000 then 'Muito Popular'
            when total_ratings >= 10000 then 'Popular'
            when total_ratings >= 1000  then 'Moderado'
            else 'Nicho'
        end as popularity_tier,

        round(
            (avg_rating * 0.5) +
            (least(log(nullif(total_ratings, 0)), 15) * 0.3) +
            (least(avg_ratings_per_movie / 100, 1) * 0.2),
            2
        ) as genre_score,

        current_timestamp as processed_at

    from genre_metrics
)

select * from with_rankings
order by total_ratings desc