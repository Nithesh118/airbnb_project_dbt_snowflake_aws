{{
  config(
    materialized = 'incremental', keys = 'host_id'
    )
}}

select 
    host_id,
    replace(host_name, ' ', '_') as host_name,
    is_superhost,
    response_rate,
    case when response_rate > 95 then 'very good'
        when response_rate > 80 then 'good'
        when response_rate > 60 then 'fair'
        else 'poor'
    end as response_rate_quality,
    CREATED_AT
from 
    {{ ref("bronze_hosts") }}