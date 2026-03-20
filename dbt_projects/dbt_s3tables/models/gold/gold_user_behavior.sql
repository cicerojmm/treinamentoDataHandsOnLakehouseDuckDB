{{
    config(
        materialized='table',
        database='s3_tables',
        schema='gold'
    )
}}

with ratings as (
    select * from {{ ref('silver_ratings') }}
),

tags as (
    select * from {{ ref('silver_tags') }}
),

movies as (
    select * from {{ ref('silver_movies') }}
),

user_rating_metrics as (
    select
        r.user_id,
        cast(count(*) as bigint)                            as total_ratings,
        cast(count(distinct r.movie_id) as bigint)          as movies_rated,
        round(avg(r.rating), 2)                             as avg_rating_given,
        round(stddev(r.rating), 2)                          as stddev_rating,
        min(r.rating)                                       as min_rating_given,
        max(r.rating)                                       as max_rating_given,

        cast(sum(case when r.rating >= 4.5 then 1 else 0 end) as bigint)                         as ratings_5_stars,
        cast(sum(case when r.rating >= 3.5 and r.rating < 4.5 then 1 else 0 end) as bigint)      as ratings_4_stars,
        cast(sum(case when r.rating >= 2.5 and r.rating < 3.5 then 1 else 0 end) as bigint)      as ratings_3_stars,
        cast(sum(case when r.rating < 2.5 then 1 else 0 end) as bigint)                          as ratings_low,

        round(100.0 * cast(sum(case when r.rating >= 4.0 then 1 else 0 end) as double) / nullif(cast(count(*) as double), 0), 2) as pct_positive_ratings,

        min(r.rating_datetime)                              as first_rating_date,
        max(r.rating_datetime)                              as last_rating_date,
        date_diff('day', min(r.rating_datetime), max(r.rating_datetime)) as days_active,

        cast(count(distinct r.rating_year) as bigint)       as years_active,
        cast(count(distinct r.rating_month) as bigint)      as months_active,

        mode() within group (order by r.hour_of_day)        as favorite_hour,
        mode() within group (order by r.day_of_week)        as favorite_day_of_week

    from ratings r
    group by r.user_id
),

user_genre_preferences as (
    select
        r.user_id,
        cast(sum(case when m.is_action   then 1 else 0 end) as bigint) as action_count,
        cast(sum(case when m.is_comedy   then 1 else 0 end) as bigint) as comedy_count,
        cast(sum(case when m.is_drama    then 1 else 0 end) as bigint) as drama_count,
        cast(sum(case when m.is_thriller then 1 else 0 end) as bigint) as thriller_count,
        cast(sum(case when m.is_romance  then 1 else 0 end) as bigint) as romance_count,
        cast(sum(case when m.is_horror   then 1 else 0 end) as bigint) as horror_count,
        cast(sum(case when m.is_scifi    then 1 else 0 end) as bigint) as scifi_count,

        round(avg(case when m.is_action   then r.rating end), 2) as action_avg_rating,
        round(avg(case when m.is_comedy   then r.rating end), 2) as comedy_avg_rating,
        round(avg(case when m.is_drama    then r.rating end), 2) as drama_avg_rating,
        round(avg(case when m.is_thriller then r.rating end), 2) as thriller_avg_rating,
        round(avg(case when m.is_romance  then r.rating end), 2) as romance_avg_rating

    from ratings r
    inner join movies m on r.movie_id = m.movie_id
    group by r.user_id
),

user_tag_metrics as (
    select
        t.user_id,
        cast(count(*) as bigint)                                                                    as total_tags_created,
        cast(count(distinct t.movie_id) as bigint)                                                  as movies_tagged,
        cast(count(distinct t.tag_normalized) as bigint)                                            as unique_tags_used,
        cast(sum(case when t.sentiment = 'Positivo' then 1 else 0 end) as bigint)                  as positive_tags,
        cast(sum(case when t.sentiment = 'Negativo' then 1 else 0 end) as bigint)                  as negative_tags,
        round(100.0 * cast(sum(case when t.sentiment = 'Positivo' then 1 else 0 end) as double) / nullif(cast(count(*) as double), 0), 2) as pct_positive_tags
    from tags t
    group by t.user_id
),

final as (
    select
        urm.user_id,

        urm.total_ratings,
        urm.movies_rated,
        urm.avg_rating_given,
        urm.stddev_rating,
        urm.pct_positive_ratings,

        urm.ratings_5_stars,
        urm.ratings_4_stars,
        urm.ratings_3_stars,
        urm.ratings_low,

        urm.first_rating_date,
        urm.last_rating_date,
        urm.days_active,
        urm.years_active,
        urm.months_active,

        round(cast(urm.total_ratings as double) / nullif(urm.days_active, 0), 2) as ratings_per_day,

        urm.favorite_hour,
        urm.favorite_day_of_week,

        ugp.action_count,
        ugp.comedy_count,
        ugp.drama_count,
        ugp.thriller_count,
        ugp.romance_count,
        ugp.horror_count,
        ugp.scifi_count,
        ugp.action_avg_rating,
        ugp.comedy_avg_rating,
        ugp.drama_avg_rating,

        case
            when ugp.action_count >= greatest(ugp.comedy_count, ugp.drama_count, ugp.thriller_count, ugp.romance_count) then 'Action'
            when ugp.comedy_count >= greatest(ugp.drama_count, ugp.thriller_count, ugp.romance_count) then 'Comedy'
            when ugp.drama_count  >= greatest(ugp.thriller_count, ugp.romance_count) then 'Drama'
            when ugp.thriller_count >= ugp.romance_count then 'Thriller'
            else 'Romance'
        end as favorite_genre,

        cast(coalesce(utm.total_tags_created, 0) as bigint)  as total_tags_created,
        cast(coalesce(utm.unique_tags_used, 0) as bigint)    as unique_tags_used,
        coalesce(utm.positive_tags, 0)                       as positive_tags,
        coalesce(utm.negative_tags, 0)                       as negative_tags,

        case
            when urm.avg_rating_given >= 4.0 then 'Otimista'
            when urm.avg_rating_given >= 3.0 then 'Equilibrado'
            else 'Crítico'
        end as user_profile,

        case
            when urm.total_ratings >= 1000 then 'Super Ativo'
            when urm.total_ratings >= 500  then 'Muito Ativo'
            when urm.total_ratings >= 100  then 'Ativo'
            when urm.total_ratings >= 20   then 'Moderado'
            else 'Casual'
        end as engagement_level,

        round(
            (ugp.action_count + ugp.comedy_count + ugp.drama_count +
             ugp.thriller_count + ugp.romance_count + ugp.horror_count + ugp.scifi_count) /
            nullif(greatest(ugp.action_count, ugp.comedy_count, ugp.drama_count,
                            ugp.thriller_count, ugp.romance_count, ugp.horror_count, ugp.scifi_count), 0),
            2
        ) as genre_diversity_score,

        current_timestamp as processed_at

    from user_rating_metrics urm
    left join user_genre_preferences ugp on urm.user_id = ugp.user_id
    left join user_tag_metrics utm on urm.user_id = utm.user_id
)

select * from final