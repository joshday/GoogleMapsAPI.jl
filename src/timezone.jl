#-----------------------------------------------------------------------------# Time Zone API
const TIMEZONE_PATH = "/maps/api/timezone/json"

"""
    timezone(location; timestamp=nothing, language=nothing, kwargs...) -> JSON.Object

Get time-zone and UTC-offset info for `location` at `timestamp`.
`location` may be any form accepted by the `convert.latlng` helper.
`timestamp` may be an integer unix time, a `DateTime`, or a string
(default is the current unix time).
"""
function timezone(
    location;
    timestamp = nothing,
    language::Union{Nothing,AbstractString} = nothing,
    client::Union{Nothing,GoogleMapsClient} = nothing,
    key::Union{Nothing,AbstractString} = nothing,
    timeout::Union{Nothing,Real} = nothing,
)
    c = _client_from_kwargs(; client, key, timeout)
    ts = as_time(something(timestamp, Base.time()))
    params = Pair{String,Any}["location" => latlng(location), "timestamp" => ts]
    isnothing(language) || push!(params, "language" => language)
    _request(c, TIMEZONE_PATH; params)
end
