{{
  config(
    materialized = 'incremental', keys = 'BOOKING_ID'
    )
}}

select 
    BOOKING_ID,
    listing_id,
    booking_date,
    {{ multiply('nights_booked', 'booking_amount') }}  as total_amount,
    cleaning_fee,
    service_fee,
    booking_status,
    CREATED_AT
from 
    {{ ref('bronze_bookings') }}

