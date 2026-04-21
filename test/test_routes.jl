using GoogleMapsAPI: _compute_routes_body

@testset "compute_routes body" begin
    body = _compute_routes_body(
        (35.9132, -79.0822), (38.9805, -77.0915);
        travel_mode = "DRIVE",
        routing_preference = "TRAFFIC_AWARE_OPTIMAL",
        departure_time = "2026-04-27T08:00:00-04:00",
        arrival_time = nothing,
        traffic_model = "BEST_GUESS",
        intermediates = [(37.0, -78.0), "Richmond, VA"],
        compute_alternative_routes = false,
        units = "METRIC",
        language_code = "en-US",
        region_code = "US",
        extra = Dict("routeModifiers" => Dict("avoidTolls" => true)),
    )
    @test body["travelMode"] == "DRIVE"
    @test body["routingPreference"] == "TRAFFIC_AWARE_OPTIMAL"
    @test body["departureTime"] == "2026-04-27T08:00:00-04:00"
    @test body["trafficModel"] == "BEST_GUESS"
    @test body["units"] == "METRIC"
    @test body["languageCode"] == "en-US"
    @test body["regionCode"] == "US"
    @test body["computeAlternativeRoutes"] === false
    @test !haskey(body, "arrivalTime")
    @test body["origin"]["location"]["latLng"]["latitude"] == 35.9132
    @test body["destination"]["location"]["latLng"]["longitude"] == -77.0915
    @test length(body["intermediates"]) == 2
    @test body["intermediates"][2]["address"] == "Richmond, VA"
    @test body["routeModifiers"]["avoidTolls"] === true

    minimal = _compute_routes_body(
        "A", "B";
        travel_mode = "DRIVE",
        routing_preference = "TRAFFIC_AWARE",
        departure_time = nothing, arrival_time = nothing,
        traffic_model = nothing, intermediates = nothing,
        compute_alternative_routes = false,
        units = nothing, language_code = nothing, region_code = nothing,
        extra = Dict{String,Any}(),
    )
    @test minimal["origin"] == Dict("address" => "A")
    @test minimal["destination"] == Dict("address" => "B")
    @test !haskey(minimal, "departureTime")
    @test !haskey(minimal, "trafficModel")
    @test !haskey(minimal, "intermediates")
end

@testset "compute_routes via _request" begin
    stub = (method, url; headers, body, readtimeout, status_exception, kwargs...) -> begin
        # Capture shape so we can inspect
        @assert method == :POST
        @assert occursin("routes.googleapis.com", url)
        @assert occursin("computeRoutes", url)
        h = Dict(headers)
        @assert h["X-Goog-Api-Key"] == "AIzaTEST"
        @assert h["X-Goog-FieldMask"] == GoogleMapsAPI.ROUTES_DEFAULT_FIELDS
        @assert h["Content-Type"] == "application/json"
        (; status=200, body=Vector{UInt8}("{\"routes\":[{\"duration\":\"1s\",\"distanceMeters\":1}]}"))
    end
    c = GoogleMapsClient(key="AIzaTEST", transport=stub, sleep=d->nothing)
    r = compute_routes("A", "B"; client=c)
    @test !isempty(r.routes)
end

if get(ENV, "GOOGLE_MAPS_API_LIVE_TESTS", "") == "1" && haskey(ENV, "GOOGLE_MAPS_API_KEY")
    @testset "live: compute_routes" begin
        r = compute_routes(
            (35.9132, -79.0822), (38.9805, -77.0915);
            routing_preference = "TRAFFIC_AWARE",
        )
        @test !isempty(r.routes)
        @test parse_duration(r.routes[1].duration) > 0
        @test r.routes[1].distanceMeters > 0
    end
end
