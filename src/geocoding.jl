#-----------------------------------------------------------------------------# Geocoding API
const GEOCODING_PATH = "/maps/api/geocode/json"

"""
    geocode(address; kwargs...) -> JSON.Object

Forward-geocode `address` via the Google Geocoding API.

### Keyword Arguments
- `components`: component filter string (e.g. `"country:US|postal_code:94043"`).
- `bounds`: viewport bias, `"lat1,lng1|lat2,lng2"`.
- `language`, `region`: IETF BCP-47 / CLDR codes.
- `extra::AbstractDict`: additional query parameters.
- `client::GoogleMapsClient`: optional; see [`GoogleMapsClient`](@ref).
- `key`: API key (default [`api_key()`](@ref)).
- `timeout`: read timeout in seconds (default 30).
"""
function geocode(
    address::AbstractString;
    components::Union{Nothing,AbstractString} = nothing,
    bounds::Union{Nothing,AbstractString} = nothing,
    language::Union{Nothing,AbstractString} = nothing,
    region::Union{Nothing,AbstractString} = nothing,
    extra::AbstractDict = Dict{String,Any}(),
    client::Union{Nothing,GoogleMapsClient} = nothing,
    key::Union{Nothing,AbstractString} = nothing,
    timeout::Union{Nothing,Real} = nothing,
)
    c = _client_from_kwargs(; client, key, timeout)
    params = Pair{String,Any}["address" => address]
    isnothing(components) || push!(params, "components" => components)
    isnothing(bounds)     || push!(params, "bounds"     => bounds)
    isnothing(language)   || push!(params, "language"   => language)
    isnothing(region)     || push!(params, "region"     => region)
    for (k, v) in extra
        push!(params, String(k) => v)
    end
    _request(c, GEOCODING_PATH; params)
end

"""
    reverse_geocode(lat, lon; kwargs...) -> JSON.Object
    reverse_geocode((lat, lon); kwargs...)

Reverse-geocode a coordinate via the Google Geocoding API.
"""
function reverse_geocode(
    lat::Real, lon::Real;
    result_type::Union{Nothing,AbstractString} = nothing,
    location_type::Union{Nothing,AbstractString} = nothing,
    language::Union{Nothing,AbstractString} = nothing,
    extra::AbstractDict = Dict{String,Any}(),
    client::Union{Nothing,GoogleMapsClient} = nothing,
    key::Union{Nothing,AbstractString} = nothing,
    timeout::Union{Nothing,Real} = nothing,
)
    c = _client_from_kwargs(; client, key, timeout)
    params = Pair{String,Any}["latlng" => latlng((lat, lon))]
    isnothing(result_type)   || push!(params, "result_type"   => result_type)
    isnothing(location_type) || push!(params, "location_type" => location_type)
    isnothing(language)      || push!(params, "language"      => language)
    for (k, v) in extra
        push!(params, String(k) => v)
    end
    _request(c, GEOCODING_PATH; params)
end

reverse_geocode(p::Tuple{<:Real,<:Real}; kwargs...) = reverse_geocode(p[1], p[2]; kwargs...)
