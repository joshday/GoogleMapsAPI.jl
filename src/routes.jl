#-----------------------------------------------------------------------------# Routes API
const ROUTES_BASE_URL = "https://routes.googleapis.com"

const ROUTES_DEFAULT_FIELDS = "routes.duration,routes.staticDuration,routes.distanceMeters,routes.polyline.encodedPolyline"

const ROUTE_MATRIX_DEFAULT_FIELDS = "originIndex,destinationIndex,duration,staticDuration,distanceMeters,status,condition"

"""
    compute_routes(origin, destination; kwargs...) -> JSON3.Object

Call the Google Routes API `v2:computeRoutes` endpoint.

`origin` and `destination` are converted with [`waypoint`](@ref) and may be
`(lat, lon)` tuples, address strings, or waypoint `Dict`s (for `placeId`, etc.).

### Keyword Arguments
- `travel_mode`: `"DRIVE"` (default), `"BICYCLE"`, `"WALK"`, `"TWO_WHEELER"`, `"TRANSIT"`.
- `routing_preference`: `"TRAFFIC_AWARE"` (default), `"TRAFFIC_AWARE_OPTIMAL"`, `"TRAFFIC_UNAWARE"`.
- `departure_time`: ISO 8601 timestamp (e.g. `"2026-04-27T08:00:00-04:00"`).
- `arrival_time`: ISO 8601 timestamp (transit only).
- `traffic_model`: `"BEST_GUESS"`, `"OPTIMISTIC"`, or `"PESSIMISTIC"`.
- `intermediates`: vector of waypoints visited between origin and destination.
- `compute_alternative_routes::Bool = false`.
- `units`: `"METRIC"` or `"IMPERIAL"`.
- `language_code`, `region_code`: IETF BCP-47 / CLDR codes.
- `field_mask`: comma-separated response field mask (default covers duration,
  staticDuration, distanceMeters, and encodedPolyline).
- `extra::AbstractDict`: merged into the request body as a last step — use for
  advanced options such as `"routeModifiers"`, `"extraComputations"`, etc.
- `client::GoogleMapsClient`: optional; see [`GoogleMapsClient`](@ref).
- `key`: API key (default [`api_key()`](@ref)).
- `timeout`: read timeout in seconds (default 30).
"""
function compute_routes(
    origin,
    destination;
    travel_mode::AbstractString = "DRIVE",
    routing_preference::AbstractString = "TRAFFIC_AWARE",
    departure_time::Union{Nothing,AbstractString} = nothing,
    arrival_time::Union{Nothing,AbstractString} = nothing,
    traffic_model::Union{Nothing,AbstractString} = nothing,
    intermediates::Union{Nothing,AbstractVector} = nothing,
    compute_alternative_routes::Bool = false,
    units::Union{Nothing,AbstractString} = nothing,
    language_code::Union{Nothing,AbstractString} = nothing,
    region_code::Union{Nothing,AbstractString} = nothing,
    field_mask::AbstractString = ROUTES_DEFAULT_FIELDS,
    extra::AbstractDict = Dict{String,Any}(),
    client::Union{Nothing,GoogleMapsClient} = nothing,
    key::Union{Nothing,AbstractString} = nothing,
    timeout::Union{Nothing,Real} = nothing,
)
    c = _client_from_kwargs(; client, key, timeout)
    body = _compute_routes_body(
        origin, destination;
        travel_mode, routing_preference, departure_time, arrival_time,
        traffic_model, intermediates, compute_alternative_routes,
        units, language_code, region_code, extra,
    )
    _request(c, "/directions/v2:computeRoutes";
             method = :POST,
             json_body = body,
             base_url = ROUTES_BASE_URL,
             auth = :header,
             extra_headers = ["X-Goog-FieldMask" => field_mask])
end

function _compute_routes_body(
    origin, destination;
    travel_mode, routing_preference, departure_time, arrival_time,
    traffic_model, intermediates, compute_alternative_routes,
    units, language_code, region_code, extra,
)
    body = Dict{String,Any}(
        "origin" => waypoint(origin),
        "destination" => waypoint(destination),
        "travelMode" => travel_mode,
        "routingPreference" => routing_preference,
        "computeAlternativeRoutes" => compute_alternative_routes,
    )
    isnothing(departure_time) || (body["departureTime"] = departure_time)
    isnothing(arrival_time)   || (body["arrivalTime"]   = arrival_time)
    isnothing(traffic_model)  || (body["trafficModel"]  = traffic_model)
    isnothing(units)          || (body["units"]         = units)
    isnothing(language_code)  || (body["languageCode"]  = language_code)
    isnothing(region_code)    || (body["regionCode"]    = region_code)
    isnothing(intermediates)  || (body["intermediates"] = [waypoint(w) for w in intermediates])
    merge!(body, extra)
    return body
end

"""
    compute_route_matrix(origins, destinations; kwargs...) -> JSON3.Array

Call the Google Routes API `v2:computeRouteMatrix` endpoint.

`origins` and `destinations` are vectors of waypoints (accepted forms as for
[`waypoint`](@ref)). Returns a flat array of matrix elements keyed by
`originIndex` / `destinationIndex`.

### Keyword Arguments
See [`compute_routes`](@ref); supports `travel_mode`, `routing_preference`,
`departure_time`, `arrival_time`, `traffic_model`, `language_code`, `region_code`,
`units`, `field_mask`, `extra`, `client`, `key`, `timeout`.
"""
function compute_route_matrix(
    origins::AbstractVector,
    destinations::AbstractVector;
    travel_mode::AbstractString = "DRIVE",
    routing_preference::AbstractString = "TRAFFIC_AWARE",
    departure_time::Union{Nothing,AbstractString} = nothing,
    arrival_time::Union{Nothing,AbstractString} = nothing,
    traffic_model::Union{Nothing,AbstractString} = nothing,
    units::Union{Nothing,AbstractString} = nothing,
    language_code::Union{Nothing,AbstractString} = nothing,
    region_code::Union{Nothing,AbstractString} = nothing,
    field_mask::AbstractString = ROUTE_MATRIX_DEFAULT_FIELDS,
    extra::AbstractDict = Dict{String,Any}(),
    client::Union{Nothing,GoogleMapsClient} = nothing,
    key::Union{Nothing,AbstractString} = nothing,
    timeout::Union{Nothing,Real} = nothing,
)
    c = _client_from_kwargs(; client, key, timeout)
    body = Dict{String,Any}(
        "origins"      => [Dict{String,Any}("waypoint" => waypoint(o)) for o in origins],
        "destinations" => [Dict{String,Any}("waypoint" => waypoint(d)) for d in destinations],
        "travelMode"        => travel_mode,
        "routingPreference" => routing_preference,
    )
    isnothing(departure_time) || (body["departureTime"] = departure_time)
    isnothing(arrival_time)   || (body["arrivalTime"]   = arrival_time)
    isnothing(traffic_model)  || (body["trafficModel"]  = traffic_model)
    isnothing(units)          || (body["units"]         = units)
    isnothing(language_code)  || (body["languageCode"]  = language_code)
    isnothing(region_code)    || (body["regionCode"]    = region_code)
    merge!(body, extra)
    _request(c, "/distanceMatrix/v2:computeRouteMatrix";
             method = :POST,
             json_body = body,
             base_url = ROUTES_BASE_URL,
             auth = :header,
             extra_headers = ["X-Goog-FieldMask" => field_mask])
end

