{{
    config(
        materialized='view'
    )
}}

with source_data as (
    select * from {{ ref('raw_customers') }}
),

cleaned as (
    select
        -- Primary Key
        customer_id,

        -- Namen bereinigen
        trim(first_name) as first_name,
        trim(last_name) as last_name,
        trim(first_name) || ' ' || trim(last_name) as full_name,

        -- Datum standardisieren und parsen
        -- Behandelt verschiedene Formate: YYYY-MM-DD und DD.MM.YYYY
        case
            when signup_date like '%-%' then
                cast(signup_date as date)
            when signup_date like '%.%' then
                cast(
                    substr(signup_date, 7, 4) || '-' ||
                    substr(signup_date, 4, 2) || '-' ||
                    substr(signup_date, 1, 2)
                    as date
                )
            else null
        end as signup_date,

        -- NULL-Werte in Country behandeln
        case
            when country = '' or country is null then 'Unknown'
            else trim(country)
        end as country,

        -- Subscription Tier standardisieren
        case
            when subscription_tier in ('Free', 'Basic', 'Premium', 'Enterprise')
                then subscription_tier
            else 'Unknown'
        end as subscription_tier,

        -- Metadaten
        current_timestamp as _loaded_at

    from source_data
    where first_name != '' -- Kunden ohne Namen ausfiltern
        and customer_id is not null
)

select * from cleaned
