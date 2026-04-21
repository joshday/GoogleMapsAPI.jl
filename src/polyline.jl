#-----------------------------------------------------------------------------# encode_polyline
"""
    encode_polyline(points) -> String

Encode a list of lat/lng points into a Google-Maps polyline string. Each
point may be a `(lat, lng)` tuple, a `NamedTuple`, or an `AbstractDict`.

See https://developers.google.com/maps/documentation/utilities/polylinealgorithm
"""
function encode_polyline(points)
    last_lat::Int = 0
    last_lng::Int = 0
    io = IOBuffer()
    for p in points
        lat_f, lng_f = normalize_lat_lng(p)
        lat = round(Int, lat_f * 1e5)
        lng = round(Int, lng_f * 1e5)
        _encode_delta(io, lat - last_lat)
        _encode_delta(io, lng - last_lng)
        last_lat = lat
        last_lng = lng
    end
    String(take!(io))
end

# Write one signed delta to `io` in Google's 5-bit chunked base-64 format.
function _encode_delta(io::IO, d::Int)
    v = d < 0 ? ~(d << 1) : (d << 1)
    while v >= 0x20
        write(io, UInt8((0x20 | (v & 0x1f)) + 63))
        v >>= 5
    end
    write(io, UInt8(v + 63))
end

#-----------------------------------------------------------------------------# decode_polyline
"""
    decode_polyline(s) -> Vector{NamedTuple{(:lat, :lng), Tuple{Float64, Float64}}}

Decode a Google-Maps polyline string into a vector of `(lat, lng)` named
tuples.
"""
function decode_polyline(s::AbstractString)
    points = Vector{@NamedTuple{lat::Float64, lng::Float64}}()
    lat::Int = 0
    lng::Int = 0
    i = firstindex(s)
    lastidx = lastindex(s)
    while i <= lastidx
        dlat, i = _decode_value(s, i)
        dlng, i = _decode_value(s, i)
        lat += dlat
        lng += dlng
        push!(points, (lat = lat * 1e-5, lng = lng * 1e-5))
    end
    points
end

# Read one signed delta from position `i` in `s`; returns `(delta, next_index)`.
function _decode_value(s::AbstractString, i::Int)
    result::Int = 0
    shift::Int = 0
    while true
        b = Int(s[i]) - 63
        i = nextind(s, i)
        result |= (b & 0x1f) << shift
        shift += 5
        (b & 0x20) == 0 && break
    end
    d = iseven(result) ? result >> 1 : ~(result >> 1)
    (d, i)
end

#-----------------------------------------------------------------------------# shortest_path
# Pick the shorter of pipe-joined coords or an `"enc:<polyline>"` string — lets Elevation callers
# stay under the 2000-char URL limit on long paths.
function shortest_path(locations)
    locs = locations isa Tuple{<:Real,<:Real} ? [locations] : locations
    encoded = "enc:" * encode_polyline(locs)
    unencoded = location_list(locs)
    length(encoded) < length(unencoded) ? encoded : unencoded
end
