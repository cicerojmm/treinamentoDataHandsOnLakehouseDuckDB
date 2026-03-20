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

movies as (
    select * from {{ ref('silver_movies') }}
),

monthly_metrics as (
    select
        r.rating_month as month,
        extract('year' from r.rating_month) as year,
        extract('month' from r.rating_month) as month_num,
        
        -- Métricas gerais
        cast(count(*) as bigint) as total_ratings,
        cast(count(distinct r.user_id) as bigint) as active_users,
        cast(count(distinct r.movie_id) as bigint) as movies_rated,
        round(avg(r.rating), 2) as avg_rating,
        
        -- Distribuição de ratings
        cast(sum(case when r.rating >= 4.5 then 1 else 0 end) as bigint) as ratings_excellent,
        cast(sum(case when r.rating >= 3.5 and r.rating < 4.5 then 1 else 0 end) as bigint) as ratings_good,
        cast(sum(case when r.rating >= 2.5 and r.rating < 3.5 then 1 else 0 end) as bigint) as ratings_average,
        cast(sum(case when r.rating < 2.5 then 1 else 0 end) as bigint) as ratings_poor,
        
        -- Métricas por gênero
        cast(sum(case when m.is_action then 1 else 0 end) as bigint) as action_ratings,
        cast(sum(case when m.is_comedy then 1 else 0 end) as bigint) as comedy_ratings,
        cast(sum(case when m.is_drama then 1 else 0 end) as bigint) as drama_ratings,
        cast(sum(case when m.is_thriller then 1 else 0 end) as bigint) as thriller_ratings,
        cast(sum(case when m.is_romance then 1 else 0 end) as bigint) as romance_ratings,
        
        -- Ratings médios por gênero
        round(avg(case when m.is_action then r.rating end), 2) as action_avg_rating,
        round(avg(case when m.is_comedy then r.rating end), 2) as comedy_avg_rating,
        round(avg(case when m.is_drama then r.rating end), 2) as drama_avg_rating,
        
        -- Filmes por década
        cast(sum(case when m.decade = 1990 then 1 else 0 end) as bigint) as ratings_1990s,
        cast(sum(case when m.decade = 2000 then 1 else 0 end) as bigint) as ratings_2000s,
        cast(sum(case when m.decade = 2010 then 1 else 0 end) as bigint) as ratings_2010s
        
    from ratings r
    inner join movies m on r.movie_id = m.movie_id
    group by r.rating_month
),

with_trends as (
    select
        *,
        -- Crescimento mês a mês
        round(100.0 * (total_ratings - lag(total_ratings) over (order by month)) / 
              nullif(lag(total_ratings) over (order by month), 0), 2) as ratings_growth_pct,
        
        round(100.0 * (active_users - lag(active_users) over (order by month)) / 
              nullif(lag(active_users) over (order by month), 0), 2) as users_growth_pct,
        
        -- Média móvel de 3 meses
        round(avg(total_ratings) over (order by month rows between 2 preceding and current row), 2) as ratings_ma3,
        round(avg(active_users) over (order by month rows between 2 preceding and current row), 2) as users_ma3,
        round(avg(avg_rating) over (order by month rows between 2 preceding and current row), 2) as avg_rating_ma3,
        
        -- Ranking de meses
        row_number() over (order by total_ratings desc) as rank_by_ratings,
        row_number() over (order by active_users desc) as rank_by_users,
        
        -- Percentual de cada gênero
        round(100.0 * action_ratings / nullif(total_ratings, 0), 2) as action_pct,
        round(100.0 * comedy_ratings / nullif(total_ratings, 0), 2) as comedy_pct,
        round(100.0 * drama_ratings / nullif(total_ratings, 0), 2) as drama_pct,
        
        current_timestamp as processed_at
        
    from monthly_metrics
)

select * from with_trends
order by month desc
