using GoogleMapsAPI: GMPoint, GMLineString, GMFeature, GMFeatureCollection,
    features, geometries, points, linestrings
using JSON

@testset "types" begin
    @testset "GMPoint" begin
        p = GMPoint(37.4, -122.1)
        @test p.lat == 37.4
        @test p.lng == -122.1
        @test occursin("37.4", sprint(show, p))
    end

    @testset "GMLineString" begin
        ls = GMLineString([GMPoint(0.0, 0.0), GMPoint(1.0, 2.0), GMPoint(3.0, 4.0)])
        @test length(ls) == 3
        @test ls[2] == GMPoint(1.0, 2.0)
        @test collect(ls) == [GMPoint(0.0, 0.0), GMPoint(1.0, 2.0), GMPoint(3.0, 4.0)]
        @test occursin("3 points", sprint(show, ls))
    end

    @testset "GMFeature / GMFeatureCollection" begin
        f = GMFeature(GMPoint(1.0, 2.0), (; name = "X"))
        @test f.geometry == GMPoint(1.0, 2.0)
        @test f.properties.name == "X"

        fc = GMFeatureCollection([f, GMFeature(nothing, (;))])
        @test length(fc) == 2
        @test collect(fc)[1] === f
        @test fc[2].geometry === nothing
    end

    @testset "features(geocode-shaped)" begin
        r = JSON.parse("""
        {
            "status":"OK",
            "results":[
                {"geometry":{"location":{"lat":37.4,"lng":-122.1}},"formatted_address":"A"},
                {"geometry":{"location":{"lat":40.0,"lng":-74.0}},"formatted_address":"B"}
            ]
        }
        """)
        fc = features(r)
        @test length(fc) == 2
        @test fc[1].geometry == GMPoint(37.4, -122.1)
        @test fc[1].properties.formatted_address == "A"
        @test fc[2].geometry.lat == 40.0
    end

    @testset "features(compute_routes-shaped)" begin
        r = JSON.parse("""
        {"routes":[{"polyline":{"encodedPolyline":"_p~iF~ps|U_ulLnnqC_mqNvxq`@"},
                    "duration":"100s","distanceMeters":1000}]}
        """)
        fc = features(r)
        @test length(fc) == 1
        @test fc[1].geometry isa GMLineString
        @test length(fc[1].geometry) == 3
        @test fc[1].properties.duration == "100s"
    end

    @testset "features(array-shaped, e.g. elevation)" begin
        r = JSON.parse("""
        [
            {"location":{"lat":1.0,"lng":2.0},"elevation":100},
            {"location":{"latitude":1.1,"longitude":2.1},"elevation":110}
        ]
        """)
        fc = features(r)
        @test length(fc) == 2
        @test fc[1].geometry == GMPoint(1.0, 2.0)
        @test fc[2].geometry == GMPoint(1.1, 2.1)  # latitude/longitude keys work
        @test fc[1].properties.elevation == 100
    end

    @testset "features(snap_to_roads-shaped)" begin
        r = JSON.parse("""
        {"snappedPoints":[
            {"location":{"latitude":60.17,"longitude":24.94},"placeId":"X"}
        ]}
        """)
        fc = features(r)
        @test length(fc) == 1
        @test fc[1].geometry == GMPoint(60.17, 24.94)
    end

    @testset "features(geolocate-shaped single feature)" begin
        r = JSON.parse("""{"location":{"lat":37.5,"lng":-122.0},"accuracy":40}""")
        fc = features(r)
        @test length(fc) == 1
        @test fc[1].geometry == GMPoint(37.5, -122.0)
        @test fc[1].properties.accuracy == 40
    end

    @testset "features(place-shaped wrapper)" begin
        r = JSON.parse("""
        {"status":"OK","result":{"geometry":{"location":{"lat":1.0,"lng":2.0}},"name":"Z"}}
        """)
        fc = features(r)
        @test length(fc) == 1
        @test fc[1].geometry == GMPoint(1.0, 2.0)
        @test fc[1].properties.name == "Z"
    end

    @testset "features(no-geometry)" begin
        r = JSON.parse("""{"timeZoneId":"America/Los_Angeles","rawOffset":-28800}""")
        fc = features(r)
        @test length(fc) == 1
        @test fc[1].geometry === nothing
        @test fc[1].properties.timeZoneId == "America/Los_Angeles"
    end

    @testset "geometries / points / linestrings" begin
        r = JSON.parse("""
        {"results":[{"geometry":{"location":{"lat":1.0,"lng":2.0}}},
                    {"polyline":{"encodedPolyline":"_p~iF~ps|U_ulLnnqC_mqNvxq`@"}}]}
        """)
        gs = geometries(r)
        @test length(gs) == 2
        pts = points(r)
        @test length(pts) == 1 + 3  # 1 point + 3 polyline vertices
        @test pts[1] == GMPoint(1.0, 2.0)
        ls = linestrings(r)
        @test length(ls) == 1
        @test length(ls[1]) == 3
    end
end
