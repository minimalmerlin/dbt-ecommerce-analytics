{{
    config(
        materialized='table'
    )
}}

with customers as (
    select * from {{ ref('stg_customers') }}
),

orders as (
    select * from {{ ref('fct_orders') }}
),

-- Komplexe Aggregationen pro Kunde
customer_metrics as (
    select
        customer_id,

        -- Order-Metriken
        count(*) as total_orders,
        count(distinct order_date_day) as unique_order_days,

        -- Revenue-Metriken
        sum(recognized_revenue) as total_lifetime_value,
        avg(recognized_revenue) as average_order_value,
        max(recognized_revenue) as largest_order_value,
        min(case when recognized_revenue > 0 then recognized_revenue end) as smallest_order_value,

        -- Zeitliche Metriken
        min(order_date) as first_order_date,
        max(order_date) as last_order_date,
        date_diff('day', min(order_date), max(order_date)) as customer_order_span_days,

        -- Order-Status-Verteilung
        count(case when order_status = 'completed' then 1 end) as completed_orders,
        count(case when order_status = 'cancelled' then 1 end) as cancelled_orders,
        count(case when order_status = 'refunded' then 1 end) as refunded_orders,
        count(case when order_status = 'pending' then 1 end) as pending_orders,

        -- Payment-Metriken
        sum(case when has_successful_payment then 1 else 0 end) as orders_with_payment,
        sum(case when has_payment_discrepancy then 1 else 0 end) as orders_with_payment_discrepancy,

        -- Payment-Method-Präferenz (häufigste Methode)
        mode() within group (order by payment_method) as preferred_payment_method,

        -- Zeitliche Verteilung
        count(case when order_day_of_week in (0, 6) then 1 end) as weekend_orders,
        count(case when order_day_of_week in (1, 2, 3, 4, 5) then 1 end) as weekday_orders,

        -- Bestellfrequenz (Orders pro Monat)
        count(*) * 1.0 / nullif(
            date_diff('month', min(order_date), max(order_date)) + 1,
            0
        ) as avg_orders_per_month

    from orders
    where is_completed = true
    group by customer_id
),

-- Zusammenführung mit Customer-Details
enriched_customers as (
    select
        -- Customer-Dimensionen
        c.customer_id,
        c.full_name,
        c.first_name,
        c.last_name,
        c.country,
        c.subscription_tier,
        c.signup_date,

        -- Zeitliche Dimensionen
        date_trunc('month', c.signup_date) as signup_month,
        extract(year from c.signup_date) as signup_year,
        date_diff('day', c.signup_date, current_date) as days_since_signup,

        -- Order-Metriken (mit Fallback auf 0 für Kunden ohne Orders)
        coalesce(m.total_orders, 0) as total_orders,
        coalesce(m.unique_order_days, 0) as unique_order_days,
        coalesce(m.total_lifetime_value, 0) as total_lifetime_value,
        coalesce(m.average_order_value, 0) as average_order_value,
        coalesce(m.largest_order_value, 0) as largest_order_value,
        coalesce(m.smallest_order_value, 0) as smallest_order_value,

        -- Zeitliche Metriken
        m.first_order_date,
        m.last_order_date,
        coalesce(m.customer_order_span_days, 0) as customer_order_span_days,

        -- Recency (Tage seit letzter Bestellung)
        case
            when m.last_order_date is not null
                then date_diff('day', m.last_order_date, current_date)
            else null
        end as days_since_last_order,

        -- Time-to-First-Order
        case
            when m.first_order_date is not null
                then date_diff('day', c.signup_date, m.first_order_date)
            else null
        end as days_to_first_order,

        -- Order-Status-Verteilung
        coalesce(m.completed_orders, 0) as completed_orders,
        coalesce(m.cancelled_orders, 0) as cancelled_orders,
        coalesce(m.refunded_orders, 0) as refunded_orders,
        coalesce(m.pending_orders, 0) as pending_orders,

        -- Payment-Metriken
        coalesce(m.orders_with_payment, 0) as orders_with_payment,
        coalesce(m.orders_with_payment_discrepancy, 0) as orders_with_payment_discrepancy,
        m.preferred_payment_method,

        -- Zeitliche Verteilung
        coalesce(m.weekend_orders, 0) as weekend_orders,
        coalesce(m.weekday_orders, 0) as weekday_orders,
        coalesce(m.avg_orders_per_month, 0) as avg_orders_per_month,

        -- Customer-Segmentierung (RFM-inspiriert)
        case
            when m.total_orders is null then 'Never Purchased'
            when m.total_orders = 1 then 'One-Time Buyer'
            when m.total_orders between 2 and 5 then 'Repeat Buyer'
            when m.total_orders between 6 and 10 then 'Frequent Buyer'
            when m.total_orders > 10 then 'VIP Customer'
        end as customer_segment,

        -- Value-Segmentierung
        case
            when m.total_lifetime_value = 0 or m.total_lifetime_value is null then 'No Value'
            when m.total_lifetime_value < 100 then 'Low Value'
            when m.total_lifetime_value < 500 then 'Medium Value'
            when m.total_lifetime_value < 2000 then 'High Value'
            when m.total_lifetime_value >= 2000 then 'Very High Value'
        end as value_segment,

        -- Recency-Segmentierung
        case
            when m.last_order_date is null then 'Never Ordered'
            when date_diff('day', m.last_order_date, current_date) <= 30 then 'Active (Last 30 days)'
            when date_diff('day', m.last_order_date, current_date) <= 90 then 'Recent (Last 90 days)'
            when date_diff('day', m.last_order_date, current_date) <= 180 then 'At Risk (90-180 days)'
            else 'Churned (180+ days)'
        end as recency_segment,

        -- Flags
        case when m.total_orders > 0 then true else false end as has_purchased,
        case when m.cancelled_orders > 0 then true else false end as has_cancelled_order,
        case when m.refunded_orders > 0 then true else false end as has_refunded_order,

        -- Metadaten
        current_timestamp as _loaded_at

    from customers c
    left join customer_metrics m on c.customer_id = m.customer_id
)

select * from enriched_customers
