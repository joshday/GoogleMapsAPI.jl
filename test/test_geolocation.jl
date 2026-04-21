@testset "geolocation" begin
    @testset "builds request" begin
        captured_url = Ref{String}("")
        captured_body = Ref{Vector{UInt8}}(UInt8[])
        stub = (method, url; headers, body, readtimeout, status_exception, kwargs...) -> begin
            @assert method == :POST
            captured_url[] = url
            captured_body[] = collect(body)
            (; status=200, body=Vector{UInt8}("{\"location\":{\"lat\":1.0,\"lng\":2.0},\"accuracy\":100}"))
        end
        c = GoogleMapsClient(key="AIzaTEST", transport=stub, sleep=d->nothing)
        r = geolocate(;
            home_mobile_country_code="310", home_mobile_network_code="410",
            radio_type="gsm", carrier="AT&T", consider_ip=true,
            client=c,
        )
        @test r.location.lat == 1.0
        @test occursin("geolocation/v1/geolocate", captured_url[])
        @test occursin("key=AIzaTEST", captured_url[])
        body_str = String(captured_body[])
        @test occursin("homeMobileCountryCode", body_str)
        @test occursin("radioType", body_str)
        @test occursin("considerIp", body_str)
    end

    @testset "403 raises _OverQueryLimit / ApiError" begin
        stub = (method, url; kwargs...) -> (; status=403,
            body=Vector{UInt8}("{\"error\":{\"errors\":[{\"reason\":\"dailyLimitExceeded\"}]}}"))
        c = GoogleMapsClient(key="AIzaTEST", transport=stub, sleep=d->nothing,
                             retry_over_query_limit=false)
        @test_throws ApiError geolocate(; consider_ip=true, client=c)
    end
end
