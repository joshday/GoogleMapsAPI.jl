#-----------------------------------------------------------------------------# GMPoint
"""
    GMPoint(lat, lng)

A single lat/lng point extracted from a GoogleMapsAPI response.
"""
struct GMPoint
    lat::Float64
    lng::Float64
end

Base.show(io::IO, p::GMPoint) = print(io, "GMPoint(lat=", p.lat, ", lng=", p.lng, ")")

#-----------------------------------------------------------------------------# GMLineString
"""
    GMLineString(points)

An ordered sequence of [`GMPoint`](@ref)s — e.g. the decoded polyline of a route.
"""
struct GMLineString
    points::Vector{GMPoint}
end

Base.length(ls::GMLineString) = length(ls.points)
Base.iterate(ls::GMLineString, st...) = iterate(ls.points, st...)
Base.getindex(ls::GMLineString, i) = ls.points[i]
Base.eltype(::Type{GMLineString}) = GMPoint
Base.show(io::IO, ls::GMLineString) = print(io, "GMLineString(", length(ls), " points)")

const GMGeometry = Union{GMPoint, GMLineString}

#-----------------------------------------------------------------------------# GMFeature
"""
    GMFeature(geometry, properties)

Geometry (a `GMPoint`, `GMLineString`, or `nothing`) paired with the raw
response object that yielded it, so callers can still reach into fields like
`name`, `place_id`, `formatted_address`, `elevation`, etc.
"""
struct GMFeature{G<:Union{Nothing,GMGeometry},P}
    geometry::G
    properties::P
end

Base.show(io::IO, f::GMFeature) =
    print(io, "GMFeature(", isnothing(f.geometry) ? "no geometry" : f.geometry, ")")

#-----------------------------------------------------------------------------# GMFeatureCollection
"""
    GMFeatureCollection(features)

Iterable collection of [`GMFeature`](@ref)s. Produced by [`features`](@ref).
"""
struct GMFeatureCollection
    features::Vector{GMFeature}
end

Base.length(fc::GMFeatureCollection) = length(fc.features)
Base.iterate(fc::GMFeatureCollection, st...) = iterate(fc.features, st...)
Base.getindex(fc::GMFeatureCollection, i) = fc.features[i]
Base.eltype(::Type{GMFeatureCollection}) = GMFeature
Base.show(io::IO, fc::GMFeatureCollection) =
    print(io, "GMFeatureCollection(", length(fc), " features)")

#-----------------------------------------------------------------------------# extraction
"""
    features(x) -> GMFeatureCollection

Normalise any GoogleMapsAPI response into a [`GMFeatureCollection`](@ref).
Handles the usual `results` / `routes` / `candidates` / `predictions` /
`snappedPoints` wrappers, plus single-feature responses (`geolocate`,
`place` → `result`) and raw arrays (`elevation`, `snap_to_roads`).
"""
features(x) = _to_feature_collection(x)

function _to_feature_collection(r::AbstractVector)
    GMFeatureCollection([_to_feature(item) for item in r])
end

function _to_feature_collection(r)
    for field in (:results, :candidates, :predictions, :routes, :snappedPoints)
        if haskey(r, field)
            return GMFeatureCollection([_to_feature(item) for item in r[field]])
        end
    end
    haskey(r, :result) && return GMFeatureCollection([_to_feature(r.result)])
    GMFeatureCollection([_to_feature(r)])
end

function _to_feature(obj)
    GMFeature(_extract_feature_geometry(obj), obj)
end

function _extract_feature_geometry(obj)
    if haskey(obj, :location)
        pt = _point_from(obj.location)
        isnothing(pt) || return pt
    end
    if haskey(obj, :geometry) && haskey(obj.geometry, :location)
        pt = _point_from(obj.geometry.location)
        isnothing(pt) || return pt
    end
    if haskey(obj, :polyline) && haskey(obj.polyline, :encodedPolyline)
        decoded = decode_polyline(String(obj.polyline.encodedPolyline))
        return GMLineString([GMPoint(p.lat, p.lng) for p in decoded])
    end
    nothing
end

function _point_from(loc)
    lat = haskey(loc, :lat) ? loc.lat :
          haskey(loc, :latitude) ? loc.latitude : nothing
    lng = haskey(loc, :lng) ? loc.lng :
          haskey(loc, :longitude) ? loc.longitude : nothing
    (isnothing(lat) || isnothing(lng)) && return nothing
    GMPoint(Float64(lat), Float64(lng))
end

"""
    geometries(x) -> Vector{Union{GMPoint, GMLineString}}

All non-missing geometries (flattened) from the response.
"""
geometries(x) = [f.geometry for f in features(x) if !isnothing(f.geometry)]

"""
    points(x) -> Vector{GMPoint}

All [`GMPoint`](@ref) geometries from the response, walking into line strings.
"""
function points(x)
    out = GMPoint[]
    for g in geometries(x)
        g isa GMPoint && push!(out, g)
        g isa GMLineString && append!(out, g.points)
    end
    out
end

"""
    linestrings(x) -> Vector{GMLineString}

All [`GMLineString`](@ref) geometries from the response.
"""
linestrings(x) = [g for g in geometries(x) if g isa GMLineString]
