module GoogleMapsAPI

using HTTP
using JSON

export
    api_key,
    waypoint,
    parse_duration,
    compute_routes,
    compute_route_matrix,
    geocode,
    reverse_geocode,
    ApiError,
    TransportError,
    HTTPError,
    RequestTimeout,
    encode_polyline,
    decode_polyline,
    GoogleMapsClient,
    set_experience_id!,
    get_experience_id,
    clear_experience_id!,
    elevation,
    elevation_along_path,
    geolocate,
    timezone,
    snap_to_roads,
    nearest_roads,
    speed_limits,
    snapped_speed_limits,
    find_place,
    places,
    places_nearby,
    place,
    places_photo,
    places_autocomplete,
    places_autocomplete_query,
    static_map,
    addressvalidation,
    mapplot,
    GMPoint,
    GMLineString,
    GMFeature,
    GMFeatureCollection,
    features,
    geometries,
    points,
    linestrings

include("exceptions.jl")
include("convert.jl")
include("polyline.jl")
include("types.jl")
include("signing.jl")
include("utils.jl")
include("client.jl")
include("elevation.jl")
include("geolocation.jl")
include("timezone.jl")
include("roads.jl")
include("places.jl")
include("staticmap.jl")
include("addressvalidation.jl")

"""
    mapplot(x; maptype="roadmap", size=(640, 640), kwargs...) -> Makie.Figure

Plot any GoogleMapsAPI response: fetches a Static Maps background sized to the
input's bounding box, then overlays markers for every lat/lng point found and
lines for every `encodedPolyline`. Accepts any of: `geocode`, `reverse_geocode`,
`compute_routes`, `compute_route_matrix`, `elevation`, `geolocate`,
`snap_to_roads`, `nearest_roads`, `places`, `places_nearby`, `find_place`,
`place`, or any `JSON.Object` containing one of the recognised shapes.

Method bodies live in the Makie package extension — call sites require
`using Makie` (plus a backend like GLMakie or CairoMakie).

Extra `kwargs` are forwarded to [`static_map`](@ref) (e.g. `scale=2`,
`language="en"`, `key=...`, `client=...`) except for the plot-styling kwargs
`markercolor`, `markersize`, `linecolor`, `linewidth`, `padding`.
"""
function mapplot end
include("routes.jl")
include("geocoding.jl")

end # module
