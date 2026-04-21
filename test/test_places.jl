@testset "places" begin
    @testset "find_place" begin
        captured = Ref{String}("")
        stub = (method, url; kwargs...) -> begin
            captured[] = url
            (; status=200, body=Vector{UInt8}("{\"status\":\"OK\",\"candidates\":[]}"))
        end
        c = GoogleMapsClient(key="AIzaTEST", transport=stub, sleep=d->nothing)
        r = find_place("pizza", "textquery"; fields=["name","geometry"], client=c)
        @test r.status == "OK"
        @test occursin("input=pizza", captured[])
        @test occursin("inputtype=textquery", captured[])
        @test occursin("fields=name%2Cgeometry", captured[]) || occursin("fields=name,geometry", captured[])
    end

    @testset "find_place validates input_type" begin
        c = GoogleMapsClient(key="AIzaTEST", transport=(m,u;kw...)->(;status=200,body=UInt8[]),
                             sleep=d->nothing)
        @test_throws ArgumentError find_place("pizza", "bad"; client=c)
    end

    @testset "find_place validates location_bias" begin
        c = GoogleMapsClient(key="AIzaTEST", transport=(m,u;kw...)->(;status=200,body=UInt8[]),
                             sleep=d->nothing)
        @test_throws ArgumentError find_place("pizza", "textquery"; location_bias="bad:1,2", client=c)
    end

    @testset "places text search" begin
        captured = Ref{String}("")
        stub = (method, url; kwargs...) -> begin
            captured[] = url
            (; status=200, body=Vector{UInt8}("{\"status\":\"OK\",\"results\":[]}"))
        end
        c = GoogleMapsClient(key="AIzaTEST", transport=stub, sleep=d->nothing)
        places("coffee"; location=(37.7749, -122.4194), radius=500, client=c)
        @test occursin("/maps/api/place/textsearch/json", captured[])
        @test occursin("query=coffee", captured[])
        @test occursin("radius=500", captured[])
    end

    @testset "places_nearby validation" begin
        c = GoogleMapsClient(key="AIzaTEST", transport=(m,u;kw...)->(;status=200,body=UInt8[]),
                             sleep=d->nothing)
        @test_throws ArgumentError places_nearby(; client=c)
        @test_throws ArgumentError places_nearby(; location=(1,2), rank_by="distance", client=c)
        @test_throws ArgumentError places_nearby(; location=(1,2), rank_by="distance",
                                                  keyword="x", radius=100, client=c)
    end

    @testset "place details" begin
        captured = Ref{String}("")
        stub = (method, url; kwargs...) -> begin
            captured[] = url
            (; status=200, body=Vector{UInt8}("{\"status\":\"OK\",\"result\":{\"name\":\"x\"}}"))
        end
        c = GoogleMapsClient(key="AIzaTEST", transport=stub, sleep=d->nothing)
        r = place("ChIJtest"; fields=["name","place_id"], client=c)
        @test r.result.name == "x"
        @test occursin("placeid=ChIJtest", captured[])
    end

    @testset "places_photo returns bytes" begin
        stub = (method, url; kwargs...) ->
            (; status=200, body=Vector{UInt8}([0x89, 0x50, 0x4e, 0x47, 0x0d]))
        c = GoogleMapsClient(key="AIzaTEST", transport=stub, sleep=d->nothing)
        bytes = places_photo("ref"; max_width=400, client=c)
        @test bytes isa Vector{UInt8}
        @test bytes[1:4] == [0x89, 0x50, 0x4e, 0x47]
    end

    @testset "places_photo requires max_width or max_height" begin
        c = GoogleMapsClient(key="AIzaTEST", transport=(m,u;kw...)->(;status=200,body=UInt8[]),
                             sleep=d->nothing)
        @test_throws ArgumentError places_photo("ref"; client=c)
    end

    @testset "autocomplete" begin
        captured = Ref{String}("")
        stub = (method, url; kwargs...) -> begin
            captured[] = url
            (; status=200, body=Vector{UInt8}("{\"status\":\"OK\",\"predictions\":[{\"description\":\"x\"}]}"))
        end
        c = GoogleMapsClient(key="AIzaTEST", transport=stub, sleep=d->nothing)
        preds = places_autocomplete("mount"; language="en", client=c)
        @test length(preds) == 1
        @test occursin("input=mount", captured[])
        @test occursin("/maps/api/place/autocomplete/json", captured[])

        places_autocomplete_query("pizza near NY"; client=c)
        @test occursin("/maps/api/place/queryautocomplete/json", captured[])
    end

    @testset "autocomplete rejects non-country components" begin
        c = GoogleMapsClient(key="AIzaTEST", transport=(m,u;kw...)->(;status=200,body=UInt8[]),
                             sleep=d->nothing)
        @test_throws ArgumentError places_autocomplete("x"; components_=Dict("postal_code"=>"94043"), client=c)
    end
end
