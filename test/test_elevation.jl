@testset "elevation" begin
    captured = Ref{String}("")
    stub = (method, url; headers, body, readtimeout, status_exception, kwargs...) -> begin
        captured[] = url
        (; status=200, body=Vector{UInt8}("{\"status\":\"OK\",\"results\":[{\"elevation\":100}]}"))
    end
    c = GoogleMapsClient(key="AIzaTEST", transport=stub, sleep=d->nothing)

    r = elevation([(38, -120), (40, -120.95)]; client=c)
    @test length(r) == 1
    @test r[1].elevation == 100
    @test occursin("/maps/api/elevation/json", captured[])
    # locations param is either pipe-joined or enc:
    @test occursin("locations=", captured[])

    r2 = elevation_along_path("abc", 5; client=c)
    @test length(r2) == 1
    @test occursin("path=enc%3Aabc", captured[]) || occursin("path=enc:abc", captured[])
    @test occursin("samples=5", captured[])

    r3 = elevation_along_path([(38, -120), (40, -120.95)], 3; client=c)
    @test occursin("samples=3", captured[])
end
