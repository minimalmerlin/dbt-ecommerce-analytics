{{
    config(
        materialized='table'
    )
}}

with orders as (
    select * from {{ ref('stg_orders') }}
),

payments as (
    select * from {{ ref('stg_payments') }}
),

customers as (
    select * from {{ ref('stg_customers') }}
),

-- Aggregiere Payments pro Order (berücksichtigt Duplikate)
payment_aggregated as (
    select
        order_id,
        count(*) as payment_count,
        sum(case when is_successful then payment_amount else 0 end) as total_paid_amount,
        sum(payment_amount) as total_payment_amount,
        max(case when is_successful then payment_method else null end) as successful_payment_method,
        max(payment_status) as final_payment_status,
        count(case when is_successful then 1 end) as successful_payment_count

    from payments
    group by order_id
),

-- Fakt-Tabelle mit allen Order-Details
fact_orders as (
    select
        -- Primärschlüssel
        o.order_id,

        -- Fremdschlüssel
        o.customer_id,
        c.country,
        c.subscription_tier,

        -- Order-Details
        o.created_at as order_date,
        o.order_amount,
        o.order_status,
        o.is_completed,

        -- Zeitdimensionen
        date_trunc('day', o.created_at) as order_date_day,
        date_trunc('week', o.created_at) as order_date_week,
        date_trunc('month', o.created_at) as order_date_month,
        date_trunc('quarter', o.created_at) as order_date_quarter,
        date_trunc('year', o.created_at) as order_date_year,

        extract(year from o.created_at) as order_year,
        extract(month from o.created_at) as order_month,
        extract(day from o.created_at) as order_day,
        extract(dow from o.created_at) as order_day_of_week,
        extract(hour from o.created_at) as order_hour,

        -- Payment-Details
        p.payment_count,
        p.total_paid_amount,
        p.total_payment_amount,
        p.successful_payment_method as payment_method,
        p.final_payment_status as payment_status,
        p.successful_payment_count,

        -- Berechnete Flags
        case
            when p.successful_payment_count > 0 then true
            else false
        end as has_successful_payment,

        case
            when o.order_amount != p.total_payment_amount then true
            else false
        end as has_payment_discrepancy,

        case
            when p.payment_count > 1 then true
            else false
        end as has_multiple_payments,

        -- Business-Metriken
        case
            when o.is_completed and p.successful_payment_count > 0
                then o.order_amount
            else 0
        end as recognized_revenue,

        -- Customer-Dimensionen
        c.full_name as customer_name,
        date_diff('day', c.signup_date, o.created_at) as days_since_customer_signup,

        -- Metadaten
        current_timestamp as _loaded_at

    from orders o
    left join payment_aggregated p on o.order_id = p.order_id
    left join customers c on o.customer_id = c.customer_id
)

select * from fact_orders
