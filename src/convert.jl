using Printf
using Dates: DateTime, datetime2unix

#-----------------------------------------------------------------------------# format_float
function format_float(x::Real)
    s = @sprintf("%.8f", Float64(x))
    s = rstrip(s, '0')
    rstrip(s, '.')
end

#-----------------------------------------------------------------------------# normalize_lat_lng
function normalize_lat_lng(t::Tuple{<:Real,<:Real})
    (Float64(t[1]), Float64(t[2]))
end

function normalize_lat_lng(p::NamedTuple)
    lat = haskey(p, :lat) ? p.lat :
          haskey(p, :latitude) ? p.latitude :
          throw(ArgumentError("lat/lng expected :lat or :latitude, got $(keys(p))"))
    lng = haskey(p, :lng) ? p.lng :
          haskey(p, :lon) ? p.lon :
          haskey(p, :longitude) ? p.longitude :
          throw(ArgumentError("lat/lng expected :lng, :lon, or :longitude, got $(keys(p))"))
    (Float64(lat), Float64(lng))
end

function normalize_lat_lng(d::AbstractDict)
    lat = haskey(d, "lat") ? d["lat"] :
          haskey(d, "latitude") ? d["latitude"] :
          haskey(d, :lat) ? d[:lat] :
          haskey(d, :latitude) ? d[:latitude] :
          throw(ArgumentError("lat/lng dict needs lat/latitude key"))
    lng = haskey(d, "lng") ? d["lng"] :
          haskey(d, "lon") ? d["lon"] :
          haskey(d, "longitude") ? d["longitude"] :
          haskey(d, :lng) ? d[:lng] :
          haskey(d, :lon) ? d[:lon] :
          haskey(d, :longitude) ? d[:longitude] :
          throw(ArgumentError("lat/lng dict needs lng/lon/longitude key"))
    (Float64(lat), Float64(lng))
end

#-----------------------------------------------------------------------------# latlng
latlng(s::AbstractString) = String(s)

function latlng(x)
    lat, lng = normalize_lat_lng(x)
    "$(format_float(lat)),$(format_float(lng))"
end

#-----------------------------------------------------------------------------# as_list
as_list(s::AbstractString) = [String(s)]
as_list(d::AbstractDict) = [d]
as_list(t::Tuple{<:Real,<:Real}) = [t]
as_list(x) = collect(x)

#-----------------------------------------------------------------------------# join_list
join_list(sep, s::AbstractString) = String(s)
join_list(sep, x) = join(as_list(x), sep)

#-----------------------------------------------------------------------------# location_list
location_list(t::Tuple{<:Real,<:Real}) = latlng(t)
location_list(s::AbstractString) = String(s)
location_list(x) = join((latlng(loc) for loc in as_list(x)), "|")

#-----------------------------------------------------------------------------# components
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
function bounds(s::AbstractString)
    if count(==('|'), s) == 1 && count(==(','), s) == 2
        return String(s)
    end
    throw(ArgumentError("bounds string must be 'lat,lng|lat,lng'"))
end

function bounds(x)
    sw = _get_field(x, :southwest, "southwest")
    ne = _get_field(x, :northeast, "northeast")
    "$(latlng(sw))|$(latlng(ne))"
end

_get_field(nt::NamedTuple, sym::Symbol, ::AbstractString) =
    haskey(nt, sym) ? nt[sym] : throw(ArgumentError("bounds missing $sym"))
_get_field(d::AbstractDict, sym::Symbol, str::AbstractString) =
    haskey(d, str)  ? d[str]  :
    haskey(d, sym)  ? d[sym]  :
    throw(ArgumentError("bounds missing $str"))

#-----------------------------------------------------------------------------# size_param
size_param(x::Integer) = "$(x)x$(x)"
size_param(t::Tuple{<:Integer,<:Integer}) = "$(t[1])x$(t[2])"
size_param(v::AbstractVector{<:Integer}) = "$(v[1])x$(v[2])"

#-----------------------------------------------------------------------------# as_time
as_time(t::DateTime) = string(floor(Int, datetime2unix(t)))
as_time(t::Real) = string(floor(Int, t))
as_time(t::AbstractString) = String(t)
