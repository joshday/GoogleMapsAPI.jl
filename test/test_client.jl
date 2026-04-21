using GoogleMapsAPI: _generate_auth_url, _urlencode_params, _request,
    _client_from_kwargs, _OverQueryLimit

# A minimal HTTP.Response-shaped stub.
struct _StubResp
    status::Int
    body::Vector{UInt8}
end
_StubResp(status::Int, s::AbstractString) = _StubResp(status, Vector{UInt8}(s))

function _make_stub(staged::Vector{_StubResp})
    calls = Ref(0)
    captured = Vector{NamedTuple}()
    stub = (method, url; headers, body, readtimeout, status_exception, kwargs...) -> begin
        calls[] += 1
        push!(captured, (; method, url, headers=copy(headers), body=copy(body)))
        staged[min(calls[], length(staged))]
    end
    stub, calls, captured
end

@testset "client" begin
    @testset "construction + validation" begin
        c = GoogleMapsClient(key="AIzaTEST")
        @test c.key == "AIzaTEST"
        @test c.timeout == 30
        @test_throws ArgumentError GoogleMapsClient(key="bad")
        @test_throws ArgumentError GoogleMapsClient()
        @test_throws ArgumentError GoogleMapsClient(key="AIzaTEST", channel="bad channel")
        c2 = GoogleMapsClient(key="AIzaTEST")
        @test c.lock !== c2.lock
    end

    @testset "experience_id" begin
        c = GoogleMapsClient(key="AIzaTEST")
        set_experience_id!(c, "xp")
        @test get_experience_id(c) == "xp"
        set_experience_id!(c, ["a", "b"])
        @test get_experience_id(c) == "a,b"
        clear_experience_id!(c)
        @test get_experience_id(c) === nothing
    end

    @testset "HMAC-signed URL" begin
        c = GoogleMapsClient(client_id="clientID",
                             client_secret="vNIXE0xscrmjlyV-12Nj_BvUPaw=")
        url = _generate_auth_url(c, "/maps/api/geocode/json",
                                 Pair{String,Any}["address" => "New York"], true)
        @test url == "/maps/api/geocode/json?address=New+York&client=clientID&signature=chaRF2hTJKOScPr-RQCEhZbSzIE="
    end

    @testset "API-key URL" begin
        c = GoogleMapsClient(key="AIzaTEST")
        url = _generate_auth_url(c, "/maps/api/geocode/json",
                                 Pair{String,Any}["address" => "foo"], true)
        @test url == "/maps/api/geocode/json?address=foo&key=AIzaTEST"
    end

    @testset "retry on 500" begin
        sleeps = Float64[]
        stub, calls, _ = _make_stub([
            _StubResp(500, "err"),
            _StubResp(500, "err"),
            _StubResp(200, "{\"status\":\"OK\",\"results\":[]}"),
        ])
        c = GoogleMapsClient(key="AIzaTEST", transport=stub, sleep=d -> push!(sleeps, d))
        body = _request(c, "/maps/api/geocode/json"; params=Pair{String,Any}["address"=>"foo"])
        @test calls[] == 3
        @test length(sleeps) == 2
        # First retry uses 0.5 * 1.5^0 * (rand+0.5) ∈ [0.25, 0.75]
        @test 0.25 <= sleeps[1] <= 0.75
        # Second retry uses 0.5 * 1.5^1 * (rand+0.5) ∈ [0.375, 1.125]
        @test 0.375 <= sleeps[2] <= 1.125
        @test body.status == "OK"
    end

    @testset "retry on OVER_QUERY_LIMIT" begin
        stub, calls, _ = _make_stub([
            _StubResp(200, "{\"status\":\"OVER_QUERY_LIMIT\"}"),
            _StubResp(200, "{\"status\":\"OK\",\"x\":1}"),
        ])
        c = GoogleMapsClient(key="AIzaTEST", transport=stub, sleep=d -> nothing)
        body = _request(c, "/x")
        @test calls[] == 2
        @test body.x == 1
    end

    @testset "no retry when retry_over_query_limit=false" begin
        stub, calls, _ = _make_stub([_StubResp(200, "{\"status\":\"OVER_QUERY_LIMIT\"}")])
        c = GoogleMapsClient(key="AIzaTEST", transport=stub, sleep=d -> nothing,
                             retry_over_query_limit=false)
        @test_throws ApiError _request(c, "/x")
        @test calls[] == 1
    end

    @testset "ApiError on REQUEST_DENIED" begin
        stub, _, _ = _make_stub([_StubResp(200, "{\"status\":\"REQUEST_DENIED\",\"error_message\":\"bad key\"}")])
        c = GoogleMapsClient(key="AIzaTEST", transport=stub, sleep=d -> nothing)
        try
            _request(c, "/x")
            error("should have thrown")
        catch e
            @test e isa ApiError
            @test e.status == "REQUEST_DENIED"
            @test e.message == "bad key"
        end
    end

    @testset "HTTPError on 404" begin
        stub, _, _ = _make_stub([_StubResp(404, "not found")])
        c = GoogleMapsClient(key="AIzaTEST", transport=stub, sleep=d -> nothing)
        @test_throws HTTPError _request(c, "/x")
    end

    @testset "header auth" begin
        stub, _, captured = _make_stub([_StubResp(200, "{\"routes\":[]}")])
        c = GoogleMapsClient(key="AIzaTEST", transport=stub, sleep=d -> nothing,
                             base_url="https://routes.googleapis.com")
        _request(c, "/foo"; method=:POST, json_body=Dict("a"=>1), auth=:header,
                 extra_headers=["X-Goog-FieldMask" => "routes.duration"])
        req = captured[1]
        h = Dict(req.headers)
        @test h["X-Goog-Api-Key"] == "AIzaTEST"
        @test h["X-Goog-FieldMask"] == "routes.duration"
        @test h["Content-Type"] == "application/json"
        @test !occursin("key=", req.url)
    end

    @testset "_client_from_kwargs preserves state on override" begin
        base = GoogleMapsClient(key="AIzaTEST")
        push!(base.sent_times, 1.0)
        c = _client_from_kwargs(client=base, timeout=5)
        @test c.timeout == 5
        @test c.sent_times === base.sent_times  # shared by reference
        @test c.lock === base.lock
    end

    @testset "_client_from_kwargs returns client unchanged when no overrides" begin
        base = GoogleMapsClient(key="AIzaTEST")
        c = _client_from_kwargs(client=base)
        @test c === base
    end

    @testset "QPS throttle" begin
        sleeps = Float64[]
        stub, _, _ = _make_stub([_StubResp(200, "{\"status\":\"OK\"}")])
        # quota=1 → 2nd call must sleep
        c = GoogleMapsClient(key="AIzaTEST", transport=stub, sleep=d -> push!(sleeps, d),
                             queries_per_second=1, queries_per_minute=60)
        _request(c, "/x")
        _request(c, "/x")
        # Second call should have triggered a throttle sleep in _record_send!
        @test any(s -> s > 0 && s <= 1.0, sleeps)
    end
end
