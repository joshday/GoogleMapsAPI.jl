@testset "timezone" begin
    captured = Ref{String}("")
    stub = (method, url; headers, body, readtimeout, status_exception, kwargs...) -> begin
        captured[] = url
        (; status=200, body=Vector{UInt8}("{\"status\":\"OK\",\"timeZoneId\":\"America/Los_Angeles\",\"rawOffset\":-28800}"))
    end
    c = GoogleMapsClient(key="AIzaTEST", transport=stub, sleep=d->nothing)

    r = timezone((39.6034, -119.6822); timestamp=1331161200, client=c)
    @test r.timeZoneId == "America/Los_Angeles"
    @test occursin("/maps/api/timezone/json", captured[])
    @test occursin("location=39.6034%2C-119.6822", captured[]) || occursin("location=39.6034,-119.6822", captured[])
    @test occursin("timestamp=1331161200", captured[])

    timezone((1, 2); client=c)  # default timestamp path — should not throw
    @test occursin("timestamp=", captured[])
end
