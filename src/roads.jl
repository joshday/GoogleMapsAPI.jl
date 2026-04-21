#-----------------------------------------------------------------------------# Roads API
const ROADS_BASE_URL = "https://roads.googleapis.com"

_roads_request(c::GoogleMapsClient, path::AbstractString; params) =
    _request(c, path; params,
             base_url = ROADS_BASE_URL,
             accepts_clientid = false,
             extract_body = _roads_extract)

"""
    snap_to_roads(path; interpolate=false, kwargs...) -> Vector (JSON3 array)

Snap a GPS path (up to 100 points) to the most likely roads travelled.
"""
function snap_to_roads(path; interpolate::Bool = false,
                       client::Union{Nothing,GoogleMapsClient} = nothing,
                       key::Union{Nothing,AbstractString} = nothing,
                       timeout::Union{Nothing,Real} = nothing)
    c = _client_from_kwargs(; client, key, timeout)
    params = Pair{String,Any}["path" => location_list(path)]
    interpolate && push!(params, "interpolate" => "true")
    get(_roads_request(c, "/v1/snapToRoads"; params), :snappedPoints, [])
end

"""
    nearest_roads(points; kwargs...) -> Vector

Closest road segment for each of up to 100 independent coordinates.
"""
function nearest_roads(points;
                       client::Union{Nothing,GoogleMapsClient} = nothing,
                       key::Union{Nothing,AbstractString} = nothing,
                       timeout::Union{Nothing,Real} = nothing)
    c = _client_from_kwargs(; client, key, timeout)
    params = Pair{String,Any}["points" => location_list(points)]
    get(_roads_request(c, "/v1/nearestRoads"; params), :snappedPoints, [])
end

"""
    speed_limits(place_ids; kwargs...) -> Vector

Posted speed limits (km/h) for up to 100 road-segment place IDs.
`place_ids` is a string or vector of strings.
"""
function speed_limits(place_ids;
                      client::Union{Nothing,GoogleMapsClient} = nothing,
                      key::Union{Nothing,AbstractString} = nothing,
                      timeout::Union{Nothing,Real} = nothing)
    c = _client_from_kwargs(; client, key, timeout)
    params = Pair{String,Any}[]
    for pid in as_list(place_ids)
        push!(params, "placeId" => pid)
    end
    get(_roads_request(c, "/v1/speedLimits"; params), :speedLimits, [])
end

"""
    snapped_speed_limits(path; kwargs...) -> JSON3.Object

Snap `path` to roads and return the matched road segments with speed limits.
Unlike `speed_limits`, returns the full body (both `speedLimits` and
`snappedPoints`).
"""
function snapped_speed_limits(path;
                              client::Union{Nothing,GoogleMapsClient} = nothing,
                              key::Union{Nothing,AbstractString} = nothing,
                              timeout::Union{Nothing,Real} = nothing)
    c = _client_from_kwargs(; client, key, timeout)
    params = Pair{String,Any}["path" => location_list(path)]
    _roads_request(c, "/v1/speedLimits"; params)
end

function _roads_extract(resp)
    body = try
        JSON3.read(resp.body)
    catch
        resp.status == 200 || throw(HTTPError(resp.status))
        throw(ApiError("UNKNOWN_ERROR", "Received a malformed response."))
    end
    if haskey(body, :error)
        status = String(body.error.status)
        msg = haskey(body.error, :message) ? String(body.error.message) : nothing
        status == "RESOURCE_EXHAUSTED" && throw(_OverQueryLimit(status, msg))
        throw(ApiError(status, msg))
    end
    resp.status == 200 || throw(HTTPError(resp.status))
    body
end
