{{
    config(
        materialized='view'
    )
}}

with source_data as (
    select * from {{ ref('raw_payments') }}
),

cleaned as (
    select
        -- Primary Key
        payment_id,

        -- Foreign Keys
        order_id,

        -- Payment Method standardisieren
        case
            when lower(payment_method) = 'credit_card' then 'credit_card'
            when lower(payment_method) = 'paypal' then 'paypal'
            when lower(payment_method) = 'bank_transfer' then 'bank_transfer'
            when lower(payment_method) = 'sepa' then 'sepa'
            when lower(payment_method) = 'invoice' then 'invoice'
            else 'unknown'
        end as payment_method,

        -- Status standardisieren
        case
            when lower(payment_status) = 'success' then 'success'
            when lower(payment_status) = 'failed' then 'failed'
            when lower(payment_status) = 'pending' then 'pending'
            when lower(payment_status) = 'refunded' then 'refunded'
            else 'unknown'
        end as payment_status,

        -- Betrag
        abs(payment_amount) as payment_amount,

        -- Abgeleitete Felder
        case
            when payment_status = 'success' then true
            else false
        end as is_successful,

        -- Metadaten
        current_timestamp as _loaded_at

    from source_data
    where payment_id is not null
        and order_id is not null
)

select * from cleaned
