@testset "parse_duration" begin
    @test parse_duration("16087s") == 16087.0
    @test parse_duration("0s") == 0.0
    @test parse_duration("12.5s") == 12.5
    @test isnan(parse_duration(nothing))
    @test isnan(parse_duration(missing))
end

@testset "waypoint" begin
    w = waypoint((35.9132, -79.0822))
    @test w["location"]["latLng"]["latitude"] == 35.9132
    @test w["location"]["latLng"]["longitude"] == -79.0822

    w = waypoint((lat = 1.0, lon = 2.0))
    @test w["location"]["latLng"]["latitude"] == 1.0
    @test w["location"]["latLng"]["longitude"] == 2.0

    w = waypoint((latitude = 1.0, longitude = 2.0))
    @test w["location"]["latLng"]["latitude"] == 1.0
    @test w["location"]["latLng"]["longitude"] == 2.0

    w = waypoint((lat = 1.0, lng = 2.0))
    @test w["location"]["latLng"]["longitude"] == 2.0

    @test waypoint("Carrboro, NC") == Dict("address" => "Carrboro, NC")

    d = Dict("placeId" => "abc")
    @test waypoint(d) === d

    @test_throws ArgumentError waypoint((foo = 1.0, bar = 2.0))
end

@testset "api_key" begin
    prior = get(ENV, "GOOGLE_MAPS_API_KEY", nothing)
    try
        delete!(ENV, "GOOGLE_MAPS_API_KEY")
        @test_throws ErrorException api_key()
        ENV["GOOGLE_MAPS_API_KEY"] = "sentinel"
        @test api_key() == "sentinel"
    finally
        isnothing(prior) ? delete!(ENV, "GOOGLE_MAPS_API_KEY") : (ENV["GOOGLE_MAPS_API_KEY"] = prior)
    end
end
