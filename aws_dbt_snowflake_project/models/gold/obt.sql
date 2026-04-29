{% set congigs = [
    {
        "table" : "airbnb.silver.silver_bookings",
        "columns" : "silver_bookings.*",
        "alias" : "silver_bookings"
    },
    {
        "table" : "airbnb.silver.silver_listing",
        "columns" : "silver_listing.host_id, silver_listing.property_type, silver_listing.room_type, silver_listing.city, silver_listing.country, silver_listing.accommodates, silver_listing.bedrooms, silver_listing.bathrooms, silver_listing.price_per_night,silver_listing.price_per_night_tag, silver_listing.created_at as listing_created_at",
        "alias" : "silver_listing",
        "join_condition" :"silver_bookings.listing_id = silver_listing.listing_id"
    },
    {
        "table" : "airbnb.silver.silver_hosts",
        "columns" : "silver_hosts.host_name, silver_hosts.is_superhost, silver_hosts.response_rate,silver_hosts.response_rate_quality , silver_hosts.created_at as host_created_at",
        "alias" : "silver_hosts",
        "join_condition" : "silver_listing.host_id = silver_hosts.host_id"
    }
] %}



select 
    {% for config in congigs %}
        {{ config.columns }}
            {% if not loop.last %} 
            ,
            {% endif %}
    {% endfor %}
from 
    {% for item in congigs %}
        {% if loop.first %}
            {{ item['table'] }} as {{ item['alias'] }}
        {% else %}
            left join {{ item['table'] }} as {{ item['alias'] }}
                on {{ item['join_condition'] }}
        {% endif %}
    {% endfor %}
    

