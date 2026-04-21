using GoogleMapsAPI: format_float, latlng, location_list, components, bounds,
    size_param, as_time, as_list, join_list, normalize_lat_lng
using Dates: DateTime

@testset "convert" begin
    @testset "format_float" begin
        @test format_float(40) == "40"
        @test format_float(40.0) == "40"
        @test format_float(40.1) == "40.1"
        @test format_float(40.001) == "40.001"
        @test format_float(40.0010) == "40.001"
        @test format_float(40.000000001) == "40"
        @test format_float(40.000000009) == "40.00000001"
    end

    @testset "normalize_lat_lng" begin
        @test normalize_lat_lng((1.0, 2.0)) == (1.0, 2.0)
        @test normalize_lat_lng((lat=1, lng=2)) == (1.0, 2.0)
        @test normalize_lat_lng((lat=1, lon=2)) == (1.0, 2.0)
        @test normalize_lat_lng((latitude=1, longitude=2)) == (1.0, 2.0)
        @test normalize_lat_lng(Dict("lat" => 1, "lng" => 2)) == (1.0, 2.0)
        @test_throws ArgumentError normalize_lat_lng((foo=1, bar=2))
    end

    @testset "latlng" begin
        @test latlng((-33.867486, 151.206990)) == "-33.867486,151.20699"
        @test latlng("Sydney") == "Sydney"
        @test latlng(Dict("lat" => -33.8, "lng" => 151.2)) == "-33.8,151.2"
    end

    @testset "location_list" begin
        @test location_list([(1.0, 2.0), (3.0, 4.0)]) == "1,2|3,4"
        @test location_list((1.0, 2.0)) == "1,2"
        @test location_list([(1, 2), "Sydney"]) == "1,2|Sydney"
    end

    @testset "components" begin
        @test components(Dict("country" => "US", "postal_code" => "94043")) ==
              "country:US|postal_code:94043"
        @test components(Dict("country" => ["US", "AU"])) == "country:AU|country:US"
    end

    @testset "bounds" begin
        b = bounds((southwest=(-34, 150), northeast=(-33, 151)))
        @test b == "-34,150|-33,151"
        @test bounds("-34,150|-33,151") == "-34,150|-33,151"
        @test bounds(Dict("southwest" => (1, 2), "northeast" => (3, 4))) == "1,2|3,4"
        @test_throws ArgumentError bounds("bad")
    end

    @testset "size_param" begin
        @test size_param(400) == "400x400"
        @test size_param((640, 480)) == "640x480"
        @test size_param([640, 480]) == "640x480"
    end

    @testset "as_time" begin
        @test as_time(1331161200) == "1331161200"
        @test as_time(DateTime(2012, 3, 8)) == "1331164800"
        @test as_time("1331161200") == "1331161200"
    end

    @testset "as_list / join_list" begin
        @test as_list("x") == ["x"]
        @test as_list([1, 2, 3]) == [1, 2, 3]
        @test join_list(",", ["a", "b"]) == "a,b"
        @test join_list(",", "ab") == "ab"
    end
end
