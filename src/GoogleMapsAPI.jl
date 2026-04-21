module GoogleMapsAPI

using HTTP
using JSON3

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
    addressvalidation

include("exceptions.jl")
include("convert.jl")
include("polyline.jl")
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
include("routes.jl")
include("geocoding.jl")

end # module
