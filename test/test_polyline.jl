using GoogleMapsAPI: shortest_path

@testset "polyline" begin
    @testset "known Google vector" begin
        pts = [(38.5, -120.2), (40.7, -120.95), (43.252, -126.453)]
        s = encode_polyline(pts)
        @test s == "_p~iF~ps|U_ulLnnqC_mqNvxq`@"
        d = decode_polyline(s)
        @test length(d) == 3
        for i in 1:3
            @test isapprox(d[i].lat, pts[i][1]; atol=1e-5)
            @test isapprox(d[i].lng, pts[i][2]; atol=1e-5)
        end
    end

    @testset "round-trip random points" begin
        # Seeded-deterministic set so the test is reproducible.
        pts = [
            (0.0, 0.0),
            (-1.1, 2.2),
            (45.5, -93.3),
            (-33.867486, 151.206990),
            (0.00001, -0.00001),
            (51.4769, -0.0005),
            (90.0, -180.0),
            (-90.0, 180.0),
        ]
        s = encode_polyline(pts)
        d = decode_polyline(s)
        @test length(d) == length(pts)
        for i in eachindex(pts)
            @test isapprox(d[i].lat, pts[i][1]; atol=1e-5)
            @test isapprox(d[i].lng, pts[i][2]; atol=1e-5)
        end
    end

    @testset "shortest_path" begin
        # Two points: pipe form wins (short)
        @test shortest_path([(1.0, 2.0), (3.0, 4.0)]) == "1,2|3,4"
        # Many points: encoded form wins
        pts = [(38.5 + 0.1i, -120.2 + 0.1i) for i in 0:9]
        result = shortest_path(pts)
        @test startswith(result, "enc:")
        # Single tuple wraps
        @test shortest_path((1.0, 2.0)) == "1,2"
    end

    @testset "empty input" begin
        @test encode_polyline(()) == ""
        @test decode_polyline("") == @NamedTuple{lat::Float64, lng::Float64}[]
    end
end
