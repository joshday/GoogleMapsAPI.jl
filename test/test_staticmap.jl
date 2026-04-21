@testset "static_map" begin
    png_bytes = Vector{UInt8}([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00])

    @testset "builds URL + returns bytes" begin
        captured = Ref{String}("")
        stub = (method, url; kwargs...) -> begin
            captured[] = url
            (; status=200, body=png_bytes)
        end
        c = GoogleMapsClient(key="AIzaTEST", transport=stub, sleep=d->nothing)
        bytes = static_map((400, 300); center=(40, -74), zoom=10, client=c)
        @test bytes == png_bytes
        @test occursin("/maps/api/staticmap", captured[])
        @test occursin("size=400x300", captured[])
        @test occursin("zoom=10", captured[])
        @test occursin("center=40%2C-74", captured[]) || occursin("center=40,-74", captured[])
    end

    @testset "validates format" begin
        c = GoogleMapsClient(key="AIzaTEST", transport=(m,u;kw...)->(;status=200,body=UInt8[]),
                             sleep=d->nothing)
        @test_throws ArgumentError static_map(400; center=(1,2), zoom=10, format="bmp", client=c)
    end

    @testset "validates maptype" begin
        c = GoogleMapsClient(key="AIzaTEST", transport=(m,u;kw...)->(;status=200,body=UInt8[]),
                             sleep=d->nothing)
        @test_throws ArgumentError static_map(400; center=(1,2), zoom=10, maptype="xx", client=c)
    end

    @testset "requires markers or center+zoom" begin
        c = GoogleMapsClient(key="AIzaTEST", transport=(m,u;kw...)->(;status=200,body=UInt8[]),
                             sleep=d->nothing)
        @test_throws ArgumentError static_map(400; client=c)
        @test_throws ArgumentError static_map(400; center=(1,2), client=c)
    end

    @testset "markers alone is valid" begin
        stub = (method, url; kwargs...) -> (; status=200, body=png_bytes)
        c = GoogleMapsClient(key="AIzaTEST", transport=stub, sleep=d->nothing)
        bytes = static_map(400; markers="color:red|40,-74", client=c)
        @test bytes == png_bytes
    end
end
