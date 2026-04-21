#-----------------------------------------------------------------------------# Elevation API
const ELEVATION_PATH = "/maps/api/elevation/json"

"""
    elevation(locations; kwargs...) -> JSON.Array

Provides elevation data for `locations`, a single location or a list of
lat/lng values (tuples, named tuples, dicts).

### Keyword Arguments
- `client::GoogleMapsClient`: optional.
- `key`, `timeout`: shortcut kwargs as for [`compute_routes`](@ref).
"""
function elevation(
    locations;
    client::Union{Nothing,GoogleMapsClient} = nothing,
    key::Union{Nothing,AbstractString} = nothing,
    timeout::Union{Nothing,Real} = nothing,
)
    c = _client_from_kwargs(; client, key, timeout)
    params = Pair{String,Any}["locations" => shortest_path(locations)]
    get(_request(c, ELEVATION_PATH; params), :results, [])
end

"""
    elevation_along_path(path, samples; kwargs...) -> JSON.Array

Provides elevation data sampled along `path`. `path` may be an encoded
polyline string (prepended with `"enc:"` internally) or a list of lat/lng
values. `samples` is the number of sample points.
"""
function elevation_along_path(
    path,
    samples::Integer;
    client::Union{Nothing,GoogleMapsClient} = nothing,
    key::Union{Nothing,AbstractString} = nothing,
    timeout::Union{Nothing,Real} = nothing,
)
    c = _client_from_kwargs(; client, key, timeout)
    path_str = path isa AbstractString ? "enc:$(path)" : shortest_path(path)
    params = Pair{String,Any}["path" => path_str, "samples" => samples]
    get(_request(c, ELEVATION_PATH; params), :results, [])
end
