module GoogleMapsAPIMakieExt

using Makie
using FileIO
using GoogleMapsAPI
using GoogleMapsAPI: static_map, decode_polyline

const _TILE_SIZE = 256

#-----------------------------------------------------------------------------# mapplot
function GoogleMapsAPI.mapplot(x;
    maptype = "roadmap",
    size = (640, 640),
    padding = 0.15,
    markercolor = :red,
    markersize = 12,
    linecolor = :dodgerblue,
    linewidth = 3,
    kwargs...,
)
    points, polylines = _extract_geometry(x)
    isempty(points) && isempty(polylines) &&
        throw(ArgumentError("mapplot: no lat/lng points or polylines found in input"))

    sw_lat, sw_lng, ne_lat, ne_lng = _bounds(points, polylines, padding)
    center_lat = (sw_lat + ne_lat) / 2
    center_lng = (sw_lng + ne_lng) / 2
    w, h = size
    zoom = _fit_zoom(sw_lat, sw_lng, ne_lat, ne_lng, w, h)

    bytes = static_map(size;
        center = (center_lat, center_lng),
        zoom = zoom,
        maptype = maptype,
        format = "png",
        kwargs...,
    )
    img = FileIO.load(FileIO.Stream{FileIO.format"PNG"}(IOBuffer(bytes)))

    fig = Figure()
    ax = Axis(fig[1, 1]; aspect = DataAspect())
    hidedecorations!(ax)
    hidespines!(ax)
    # PNG rows run top-to-bottom; rotr90 puts the matrix into the (i=x, j=y) layout
    # Makie's `image!` expects, with i increasing rightward and j increasing upward.
    image!(ax, 0 .. w, 0 .. h, rotr90(img))

    if !isempty(points)
        pxs = Float64[]
        pys = Float64[]
        for (lat, lng) in points
            px, py = _latlng_to_pixel(lat, lng, center_lat, center_lng, zoom, w, h)
            push!(pxs, px)
            push!(pys, h - py)
        end
        scatter!(ax, pxs, pys;
                 color = markercolor, markersize = markersize,
                 strokecolor = :white, strokewidth = 2)
    end
    for line in polylines
        pxs = Float64[]
        pys = Float64[]
        for (lat, lng) in line
            px, py = _latlng_to_pixel(lat, lng, center_lat, center_lng, zoom, w, h)
            push!(pxs, px)
            push!(pys, h - py)
        end
        lines!(ax, pxs, pys; color = linecolor, linewidth = linewidth)
    end

    xlims!(ax, 0, w)
    ylims!(ax, 0, h)
    fig
end

#-----------------------------------------------------------------------------# geometry extraction
# Walk any GoogleMapsAPI response (JSON.Object, JSON.Array, or raw Dict/Vector)
# and pull out lat/lng points plus any encoded polylines we can find.
function _extract_geometry(x)
    points = Tuple{Float64,Float64}[]
    polylines = Vector{Tuple{Float64,Float64}}[]
    _walk(x, points, polylines)
    points, polylines
end

function _walk(x::AbstractVector, points, polylines)
    for item in x
        _walk(item, points, polylines)
    end
end

function _walk(x, points, polylines)
    # Anything non-object-like bottoms out here.
    _has_key(x, :location)   && _extract_point(x.location, points)
    _has_key(x, :geometry)   && _has_key(x.geometry, :location) &&
        _extract_point(x.geometry.location, points)
    _has_key(x, :polyline)   && _has_key(x.polyline, :encodedPolyline) &&
        _extract_polyline(String(x.polyline.encodedPolyline), polylines)
    for field in (:routes, :results, :candidates, :snappedPoints, :predictions)
        _has_key(x, field) && _walk(x[field], points, polylines)
    end
    _has_key(x, :result) && _walk(x.result, points, polylines)
end

# Safe haskey for arbitrary JSON.Object-ish values; non-dicts return false.
_has_key(x, k) = try
    haskey(x, k)
catch
    false
end

function _extract_point(loc, points)
    lat = _has_key(loc, :lat) ? loc.lat :
          _has_key(loc, :latitude) ? loc.latitude : nothing
    lng = _has_key(loc, :lng) ? loc.lng :
          _has_key(loc, :longitude) ? loc.longitude : nothing
    if !isnothing(lat) && !isnothing(lng)
        push!(points, (Float64(lat), Float64(lng)))
    end
end

function _extract_polyline(encoded::AbstractString, polylines)
    decoded = decode_polyline(encoded)
    push!(polylines, [(p.lat, p.lng) for p in decoded])
end

#-----------------------------------------------------------------------------# bounds + zoom + projection
# Smallest lat/lng rectangle that contains every point/polyline vertex, padded.
function _bounds(points, polylines, padding)
    lats = Float64[]
    lngs = Float64[]
    for (lat, lng) in points
        push!(lats, lat)
        push!(lngs, lng)
    end
    for line in polylines, (lat, lng) in line
        push!(lats, lat)
        push!(lngs, lng)
    end
    sw_lat, ne_lat = extrema(lats)
    sw_lng, ne_lng = extrema(lngs)
    lat_pad = max((ne_lat - sw_lat) * padding, 0.002)
    lng_pad = max((ne_lng - sw_lng) * padding, 0.002)
    (sw_lat - lat_pad, sw_lng - lng_pad, ne_lat + lat_pad, ne_lng + lng_pad)
end

# Web-Mercator helpers (Google Static Maps uses 256-px tiles at zoom 0).
_project_lng(lng) = (lng + 180) / 360
_project_lat(lat) = (1 - log(tan(π / 4 + lat * π / 360)) / π) / 2

# Largest integer zoom at which the bounding box fits inside a `(map_w, map_h)` image.
function _fit_zoom(sw_lat, sw_lng, ne_lat, ne_lng, map_w, map_h)
    lng_frac = (ne_lng - sw_lng) / 360
    lat_frac = abs(_project_lat(sw_lat) - _project_lat(ne_lat))
    lng_zoom = lng_frac <= 0 ? 21.0 : log2(map_w / (_TILE_SIZE * lng_frac))
    lat_zoom = lat_frac <= 0 ? 21.0 : log2(map_h / (_TILE_SIZE * lat_frac))
    clamp(floor(Int, min(lng_zoom, lat_zoom)), 0, 21)
end

# Map (lat, lng) → pixel in the static-map image (origin top-left, y growing down).
function _latlng_to_pixel(lat, lng, center_lat, center_lng, zoom, map_w, map_h)
    world = _TILE_SIZE * 2.0^zoom
    dx = (_project_lng(lng) - _project_lng(center_lng)) * world
    dy = (_project_lat(lat) - _project_lat(center_lat)) * world
    (map_w / 2 + dx, map_h / 2 + dy)
end

end # module
