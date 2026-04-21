using GoogleMapsAPI
using Test

@testset "GoogleMapsAPI" begin
    include("test_utils.jl")
    include("test_exceptions.jl")
    include("test_convert.jl")
    include("test_polyline.jl")
    include("test_signing.jl")
    include("test_client.jl")
    include("test_routes.jl")
    include("test_geocoding.jl")
    include("test_elevation.jl")
    include("test_geolocation.jl")
    include("test_timezone.jl")
    include("test_roads.jl")
    include("test_places.jl")
    include("test_staticmap.jl")
    include("test_addressvalidation.jl")
end
