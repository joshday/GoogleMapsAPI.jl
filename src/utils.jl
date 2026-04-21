#-----------------------------------------------------------------------------# API key
"""
    api_key() -> String

Return the Google Maps API key from `ENV["GOOGLE_MAPS_API_KEY"]`. Throws if unset.

### Examples
```julia
key = GoogleMapsAPI.api_key()
```
"""
function api_key()
    return get(ENV, "GOOGLE_MAPS_API_KEY") do
        error("GOOGLE_MAPS_API_KEY not set. Export it in your shell, " *
              "or pass `key=\"...\"` explicitly.")
    end
end

#-----------------------------------------------------------------------------# Waypoint
"""
    waypoint(x) -> Dict

Convert `x` to a Routes API waypoint `Dict`.

Accepted inputs:
- `(lat, lon)` `Tuple` or `NamedTuple` with `:lat`/`:lon` (or `:latitude`/`:longitude`) → `latLng` waypoint
- `AbstractString` → `address` waypoint
- `AbstractDict` → returned as-is (escape hatch for `placeId`, `polyline`, etc.)

### Examples
```julia
waypoint((35.9132, -79.0822))
waypoint("1600 Amphitheatre Pkwy, Mountain View, CA")
waypoint(Dict("placeId" => "ChIJj61dQgK6j4AR4GeTYWZsKWw"))
```
"""
waypoint(p::Tuple{<:Real,<:Real}) = _latlng_waypoint(p[1], p[2])
waypoint(p::NamedTuple) = _latlng_waypoint(normalize_lat_lng(p)...)
waypoint(s::AbstractString) = Dict{String,Any}("address" => String(s))
waypoint(d::AbstractDict) = d

# Build the `{ location: { latLng: {latitude, longitude} } }` Dict shape the Routes API expects.
_latlng_waypoint(lat::Real, lon::Real) = Dict{String,Any}(
    "location" => Dict{String,Any}(
        "latLng" => Dict{String,Any}("latitude" => lat, "longitude" => lon),
    ),
)

#-----------------------------------------------------------------------------# Duration parsing
"""
    parse_duration(s) -> Float64

Parse a Google duration string (e.g. `"16087s"`, `"16087.5s"`) into seconds.
Returns `Float64` seconds. Returns `NaN` for `nothing`/`missing`.

### Examples
```julia
parse_duration("16087s")     # 16087.0
parse_duration("0.5s")       # 0.5
```
"""
parse_duration(s::AbstractString) = parse(Float64, rstrip(s, 's'))
parse_duration(::Nothing) = NaN
parse_duration(::Missing) = NaN
