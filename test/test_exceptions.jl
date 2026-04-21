@testset "exceptions" begin
    @test ApiError <: Exception
    @test TransportError <: Exception
    @test HTTPError <: Exception
    @test RequestTimeout <: Exception
    @test GoogleMapsAPI._OverQueryLimit <: Exception

    e = ApiError("OVER_QUERY_LIMIT", "too many")
    s = sprint(showerror, e)
    @test occursin("OVER_QUERY_LIMIT", s)
    @test occursin("too many", s)

    e2 = ApiError("ZERO_RESULTS")
    @test e2.message === nothing
    @test occursin("ZERO_RESULTS", sprint(showerror, e2))

    @test HTTPError(500).status == 500
    @test occursin("500", sprint(showerror, HTTPError(500)))

    @test sprint(showerror, RequestTimeout()) == "RequestTimeout()"

    t = TransportError("boom")
    @test t.cause == "boom"
    @test occursin("boom", sprint(showerror, t))
end
