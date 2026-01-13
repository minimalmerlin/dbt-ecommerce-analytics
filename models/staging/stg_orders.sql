{{
    config(
        materialized='view'
    )
}}

with source_data as (
    select * from {{ ref('raw_orders') }}
),

cleaned as (
    select
        -- Primary Key
        order_id,

        -- Foreign Keys
        customer_id,

        -- Beträge bereinigen (negative Werte korrigieren)
        abs(order_amount) as order_amount,

        -- Datum standardisieren
        case
            when created_at like '%-%' then
                cast(created_at as timestamp)
            when created_at like '%/%' then
                cast(
                    substr(created_at, 7, 4) || '-' ||
                    substr(created_at, 4, 2) || '-' ||
                    substr(created_at, 1, 2) || ' 00:00:00'
                    as timestamp
                )
            else null
        end as created_at,

        -- Status bereinigen und standardisieren
        case
            when order_status = '' or order_status is null then 'unknown'
            when lower(order_status) = 'completed' then 'completed'
            when lower(order_status) = 'pending' then 'pending'
            when lower(order_status) = 'cancelled' then 'cancelled'
            when lower(order_status) = 'refunded' then 'refunded'
            else 'unknown'
        end as order_status,

        -- Abgeleitete Felder
        case
            when order_status in ('completed', 'refunded') then true
            else false
        end as is_completed,

        -- Metadaten
        current_timestamp as _loaded_at

    from source_data
    where order_id is not null
        and customer_id is not null
        and order_amount is not null
)

select * from cleaned
