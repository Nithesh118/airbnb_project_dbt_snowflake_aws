{{
  config(
    materialized = 'incremental', keys = 'LISTING_ID'
    )
}}

select 
    listing_id,
    host_id,
    property_type,
    room_type,
    city,
    country,
    accommodates,
    bedrooms,
    bathrooms,
    price_per_night,
    {{ tag('cast(price_per_night as int)') }} as price_per_night_tag,
    CREATED_AT
from 
    {{ ref('bronze_listings') }}