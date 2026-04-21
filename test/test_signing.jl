using GoogleMapsAPI: sign_hmac

@testset "signing" begin
    # Reference vector verified during planning against both Python and
    # an ad-hoc Julia shell.
    @test sign_hmac(
        "vNIXE0xscrmjlyV-12Nj_BvUPaw=",
        "/maps/api/geocode/json?address=New+York&client=clientID",
    ) == "chaRF2hTJKOScPr-RQCEhZbSzIE="
end
