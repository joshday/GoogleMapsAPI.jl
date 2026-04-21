@testset "addressvalidation" begin
    captured_url = Ref{String}("")
    captured_body = Ref{Vector{UInt8}}(UInt8[])
    stub = (method, url; headers, body, readtimeout, status_exception, kwargs...) -> begin
        @assert method == :POST
        captured_url[] = url
        captured_body[] = collect(body)
        (; status=200, body=Vector{UInt8}("{\"result\":{\"verdict\":{\"addressComplete\":true},\"address\":{\"formattedAddress\":\"X\"}}}"))
    end
    c = GoogleMapsClient(key="AIzaTEST", transport=stub, sleep=d->nothing)

    r = addressvalidation(["1600 Amphitheatre Pkwy", "Mountain View, CA 94043"];
                          region_code="US", enable_usps_cass=true, client=c)
    @test r.result.address.formattedAddress == "X"
    @test occursin("addressvalidation.googleapis.com", captured_url[])
    @test occursin("/v1:validateAddress", captured_url[])
    @test occursin("key=AIzaTEST", captured_url[])
    body_str = String(captured_body[])
    @test occursin("addressLines", body_str)
    @test occursin("regionCode", body_str)
    @test occursin("enableUspsCass", body_str)

    # String input wraps
    addressvalidation("123 Main St"; client=c)
    @test occursin("\"addressLines\":[\"123 Main St\"]", String(captured_body[]))
end
