@testset "roads" begin
    @testset "snap_to_roads" begin
        captured = Ref{String}("")
        stub = (method, url; kwargs...) -> begin
            captured[] = url
            (; status=200, body=Vector{UInt8}("{\"snappedPoints\":[{\"location\":{\"latitude\":1,\"longitude\":2}}]}"))
        end
        c = GoogleMapsClient(key="AIzaTEST", transport=stub, sleep=d->nothing)
        r = snap_to_roads([(1.0, 2.0), (3.0, 4.0)]; interpolate=true, client=c)
        @test length(r) == 1
        @test occursin("roads.googleapis.com", captured[])
        @test occursin("/v1/snapToRoads", captured[])
        @test occursin("interpolate=true", captured[])
        @test occursin("path=", captured[])
    end

    @testset "nearest_roads" begin
        stub = (method, url; kwargs...) ->
            (; status=200, body=Vector{UInt8}("{\"snappedPoints\":[]}"))
        c = GoogleMapsClient(key="AIzaTEST", transport=stub, sleep=d->nothing)
        r = nearest_roads([(1.0, 2.0)]; client=c)
        @test r == []
    end

    @testset "speed_limits repeats placeId" begin
        captured = Ref{String}("")
        stub = (method, url; kwargs...) -> begin
            captured[] = url
            (; status=200, body=Vector{UInt8}("{\"speedLimits\":[]}"))
        end
        c = GoogleMapsClient(key="AIzaTEST", transport=stub, sleep=d->nothing)
        speed_limits(["a", "b", "c"]; client=c)
        # three placeId= params
        @test count(p -> occursin("placeId=", p), split(captured[], "&")) == 3
    end

    @testset "snapped_speed_limits returns body" begin
        stub = (method, url; kwargs...) ->
            (; status=200, body=Vector{UInt8}("{\"speedLimits\":[],\"snappedPoints\":[]}"))
        c = GoogleMapsClient(key="AIzaTEST", transport=stub, sleep=d->nothing)
        body = snapped_speed_limits([(1.0, 2.0), (3.0, 4.0)]; client=c)
        @test haskey(body, :speedLimits)
        @test haskey(body, :snappedPoints)
    end

    @testset "error.status -> ApiError" begin
        stub = (method, url; kwargs...) ->
            (; status=400, body=Vector{UInt8}("{\"error\":{\"status\":\"INVALID_ARGUMENT\",\"message\":\"bad\"}}"))
        c = GoogleMapsClient(key="AIzaTEST", transport=stub, sleep=d->nothing)
        try
            snap_to_roads([(1.0, 2.0)]; client=c)
            error("should have thrown")
        catch e
            @test e isa ApiError
            @test e.status == "INVALID_ARGUMENT"
            @test e.message == "bad"
        end
    end

    @testset "RESOURCE_EXHAUSTED -> _OverQueryLimit (re-wrapped when no retry)" begin
        stub = (method, url; kwargs...) ->
            (; status=429, body=Vector{UInt8}("{\"error\":{\"status\":\"RESOURCE_EXHAUSTED\",\"message\":\"slow down\"}}"))
        c = GoogleMapsClient(key="AIzaTEST", transport=stub, sleep=d->nothing,
                             retry_over_query_limit=false)
        @test_throws ApiError snap_to_roads([(1.0, 2.0)]; client=c)
    end
end
