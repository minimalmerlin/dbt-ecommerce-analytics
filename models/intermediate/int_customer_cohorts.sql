{{
    config(
        materialized='view'
    )
}}

with customers as (
    select * from {{ ref('stg_customers') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
),

-- Cohorten-Analyse: Gruppierung nach Signup-Monat
customer_cohorts as (
    select
        customer_id,
        full_name,
        country,
        subscription_tier,
        signup_date,

        -- Cohort-Dimensionen mit DATE_TRUNC
        date_trunc('month', signup_date) as cohort_month,
        date_trunc('quarter', signup_date) as cohort_quarter,
        date_trunc('year', signup_date) as cohort_year,

        -- Zeitbasierte Segmente
        extract(year from signup_date) as signup_year,
        extract(month from signup_date) as signup_month,
        extract(quarter from signup_date) as signup_quarter,

        -- Wochentag des Signups
        case extract(dow from signup_date)
            when 0 then 'Sunday'
            when 1 then 'Monday'
            when 2 then 'Tuesday'
            when 3 then 'Wednesday'
            when 4 then 'Thursday'
            when 5 then 'Friday'
            when 6 then 'Saturday'
        end as signup_day_of_week

    from customers
    where signup_date is not null
),

-- Order-Metriken pro Kunde
customer_order_metrics as (
    select
        customer_id,
        min(created_at) as first_order_date,
        max(created_at) as last_order_date,
        count(*) as total_orders,
        sum(order_amount) as total_order_value,
        avg(order_amount) as avg_order_value

    from orders
    where is_completed = true
    group by customer_id
),

-- Window Functions für Cohorten-Analyse
cohort_analysis as (
    select
        c.*,
        om.first_order_date,
        om.last_order_date,
        om.total_orders,
        om.total_order_value,
        om.avg_order_value,

        -- Time-to-First-Order (Tage zwischen Signup und erster Bestellung)
        case
            when om.first_order_date is not null
                then date_diff('day', c.signup_date, om.first_order_date)
            else null
        end as days_to_first_order,

        -- Recency (Tage seit letzter Bestellung)
        case
            when om.last_order_date is not null
                then date_diff('day', om.last_order_date, current_date)
            else null
        end as days_since_last_order,

        -- Customer Lifetime (Tage seit Signup)
        date_diff('day', c.signup_date, current_date) as customer_lifetime_days,

        -- Window Function: Ranking innerhalb der Kohorte nach Total Order Value
        row_number() over (
            partition by c.cohort_month
            order by coalesce(om.total_order_value, 0) desc
        ) as rank_in_cohort_by_value,

        -- Window Function: Percentile Rank innerhalb der Kohorte
        percent_rank() over (
            partition by c.cohort_month
            order by coalesce(om.total_order_value, 0)
        ) as percentile_rank_in_cohort,

        -- Window Function: Durchschnittlicher Order Value der Kohorte
        avg(om.total_order_value) over (
            partition by c.cohort_month
        ) as cohort_avg_order_value,

        -- Window Function: Erste Customer ID in der Kohorte (ältester Kunde)
        first_value(c.customer_id) over (
            partition by c.cohort_month
            order by c.signup_date
            rows between unbounded preceding and unbounded following
        ) as first_customer_in_cohort,

        -- Anzahl Kunden pro Kohorte
        count(*) over (partition by c.cohort_month) as cohort_size,

        -- Customer Segmentierung basierend auf Verhalten
        case
            when om.total_orders is null then 'Never Purchased'
            when om.total_orders = 1 then 'One-Time Buyer'
            when om.total_orders between 2 and 5 then 'Repeat Buyer'
            when om.total_orders > 5 then 'Loyal Customer'
        end as customer_segment

    from customer_cohorts c
    left join customer_order_metrics om
        on c.customer_id = om.customer_id
)

select * from cohort_analysis
