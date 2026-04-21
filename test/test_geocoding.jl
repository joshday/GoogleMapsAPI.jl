@testset "geocode via _request" begin
    captured = Ref{String}("")
    stub = (method, url; headers, body, readtimeout, status_exception, kwargs...) -> begin
        captured[] = url
        (; status=200, body=Vector{UInt8}("{\"status\":\"OK\",\"results\":[]}"))
    end
    c = GoogleMapsClient(key="AIzaTEST", transport=stub, sleep=d->nothing)
    r = geocode("foo"; client=c)
    @test r.status == "OK"
    @test occursin("address=foo", captured[])
    @test occursin("key=AIzaTEST", captured[])
end

@testset "reverse_geocode via _request" begin
    captured = Ref{String}("")
    stub = (method, url; headers, body, readtimeout, status_exception, kwargs...) -> begin
        captured[] = url
        (; status=200, body=Vector{UInt8}("{\"status\":\"OK\",\"results\":[]}"))
    end
    c = GoogleMapsClient(key="AIzaTEST", transport=stub, sleep=d->nothing)
    r = reverse_geocode(1.0, 2.0; client=c)
    @test r.status == "OK"
    @test occursin("latlng=1.0%2C2.0", captured[]) || occursin("latlng=1.0,2.0", captured[])
end

if get(ENV, "GOOGLE_MAPS_API_LIVE_TESTS", "") == "1" && haskey(ENV, "GOOGLE_MAPS_API_KEY")
    @testset "live: geocode" begin
        r = geocode("1600 Amphitheatre Pkwy, Mountain View, CA")
        @test r.status == "OK"
        @test !isempty(r.results)
    end
end
