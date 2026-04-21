using Printf
using Dates: DateTime, datetime2unix

#-----------------------------------------------------------------------------# format_float
# Format a lat/lng float as a short string (max 8 decimals, trailing zeros and dot stripped)
# to keep URLs within the Maps API 2000-char limit.
function format_float(x::Real)
    s = @sprintf("%.8f", Float64(x))
    s = rstrip(s, '0')
    rstrip(s, '.')
end

#-----------------------------------------------------------------------------# normalize_lat_lng
# Return `x[k]` for the first key that exists, else `nothing`. Works on both NamedTuple
# (Symbol keys) and AbstractDict (may mix String/Symbol keys).
function _first_key(x, keys...)
    for k in keys
        haskey(x, k) && return x[k]
    end
    nothing
end

# Coerce any supported lat/lng representation (tuple, NamedTuple, dict with various key spellings)
# to a plain `(Float64, Float64)` tuple.
normalize_lat_lng(t::Tuple{<:Real,<:Real}) = (Float64(t[1]), Float64(t[2]))

function normalize_lat_lng(p::NamedTuple)
    lat = _first_key(p, :lat, :latitude)
    isnothing(lat) && throw(ArgumentError("lat/lng expected :lat or :latitude, got $(keys(p))"))
    lng = _first_key(p, :lng, :lon, :longitude)
    isnothing(lng) && throw(ArgumentError("lat/lng expected :lng, :lon, or :longitude, got $(keys(p))"))
    (Float64(lat), Float64(lng))
end

function normalize_lat_lng(d::AbstractDict)
    lat = _first_key(d, "lat", "latitude", :lat, :latitude)
    isnothing(lat) && throw(ArgumentError("lat/lng dict needs lat/latitude key"))
    lng = _first_key(d, "lng", "lon", "longitude", :lng, :lon, :longitude)
    isnothing(lng) && throw(ArgumentError("lat/lng dict needs lng/lon/longitude key"))
    (Float64(lat), Float64(lng))
end

#-----------------------------------------------------------------------------# latlng
# Render a location as the comma-separated `"lat,lng"` string expected in query params
# (strings pass through unchanged — callers may already have an address or place_id).
latlng(s::AbstractString) = String(s)

function latlng(x)
    lat, lng = normalize_lat_lng(x)
    "$(format_float(lat)),$(format_float(lng))"
end

#-----------------------------------------------------------------------------# as_list
# Wrap `x` in a single-element vector unless it is already iterable-as-a-collection
# (strings, dicts, and single lat/lng tuples are treated as scalars).
as_list(s::AbstractString) = [String(s)]
as_list(d::AbstractDict) = [d]
as_list(t::Tuple{<:Real,<:Real}) = [t]
as_list(x) = collect(x)

#-----------------------------------------------------------------------------# join_list
# Join `x` with `sep`, treating a bare string as already-joined.
join_list(sep, s::AbstractString) = String(s)
join_list(sep, x) = join(as_list(x), sep)

#-----------------------------------------------------------------------------# location_list
# Pipe-join a list of locations into the `"lat1,lng1|lat2,lng2|..."` form Maps APIs accept.
location_list(t::Tuple{<:Real,<:Real}) = latlng(t)
location_list(s::AbstractString) = String(s)
location_list(x) = join((latlng(loc) for loc in as_list(x)), "|")

#-----------------------------------------------------------------------------# components
# Encode a component filter dict as `"key:value|key:value|..."`, sorted and with vector values expanded.
function components(d::AbstractDict)
    parts = String[]
    for (k, v) in d
        for item in as_list(v)
            push!(parts, "$(k):$(item)")
        end
    end
    sort!(parts)
    join(parts, "|")
end

#-----------------------------------------------------------------------------# bounds
# Render a viewport-bias rectangle as `"sw_lat,sw_lng|ne_lat,ne_lng"`.
function bounds(s::AbstractString)
    if count(==('|'), s) == 1 && count(==(','), s) == 2
        return String(s)
    end
    throw(ArgumentError("bounds string must be 'lat,lng|lat,lng'"))
end

function bounds(x)
    "$(latlng(_require_corner(x, :southwest)))|$(latlng(_require_corner(x, :northeast)))"
end

# Fetch `:southwest`/`:northeast` from a NamedTuple or dict (string or Symbol key); throw if missing.
function _require_corner(x, sym::Symbol)
    v = _first_key(x, sym, String(sym))
    isnothing(v) && throw(ArgumentError("bounds missing $(String(sym))"))
    v
end

#-----------------------------------------------------------------------------# size_param
# Render a Maps-Static `size` parameter as `"WxH"` from either an int (square) or a `(w, h)` pair.
size_param(x::Integer) = "$(x)x$(x)"
size_param(t::Tuple{<:Integer,<:Integer}) = "$(t[1])x$(t[2])"
size_param(v::AbstractVector{<:Integer}) = "$(v[1])x$(v[2])"

#-----------------------------------------------------------------------------# as_time
# Coerce DateTime / Real / String to the integer-seconds-since-epoch string used by the Time Zone API.
as_time(t::DateTime) = string(floor(Int, datetime2unix(t)))
as_time(t::Real) = string(floor(Int, t))
as_time(t::AbstractString) = String(t)
