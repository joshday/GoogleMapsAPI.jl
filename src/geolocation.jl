#-----------------------------------------------------------------------------# Geolocation API
const GEOLOCATION_BASE_URL = "https://www.googleapis.com"
const GEOLOCATION_PATH = "/geolocation/v1/geolocate"

"""
    geolocate(; kwargs...) -> JSON.Object

Locate a device from cell-tower / WiFi data. POST to
`https://www.googleapis.com/geolocation/v1/geolocate`.

### Keyword Arguments
- `home_mobile_country_code`, `home_mobile_network_code`: strings.
- `radio_type`: `"lte"`, `"gsm"`, `"cdma"`, or `"wcdma"`.
- `carrier`: carrier name.
- `consider_ip`: `Bool` — fall back to IP geolocation.
- `cell_towers`: vector of cell tower dicts.
- `wifi_access_points`: vector of WiFi AP dicts.
- `client`, `key`, `timeout`: standard shortcuts.
"""
function geolocate(;
    home_mobile_country_code::Union{Nothing,AbstractString} = nothing,
    home_mobile_network_code::Union{Nothing,AbstractString} = nothing,
    radio_type::Union{Nothing,AbstractString} = nothing,
    carrier::Union{Nothing,AbstractString} = nothing,
    consider_ip::Union{Nothing,Bool} = nothing,
    cell_towers::Union{Nothing,AbstractVector} = nothing,
    wifi_access_points::Union{Nothing,AbstractVector} = nothing,
    client::Union{Nothing,GoogleMapsClient} = nothing,
    key::Union{Nothing,AbstractString} = nothing,
    timeout::Union{Nothing,Real} = nothing,
)
    c = _client_from_kwargs(; client, key, timeout)
    body = Dict{String,Any}()
    isnothing(home_mobile_country_code) || (body["homeMobileCountryCode"] = home_mobile_country_code)
    isnothing(home_mobile_network_code) || (body["homeMobileNetworkCode"] = home_mobile_network_code)
    isnothing(radio_type)         || (body["radioType"]         = radio_type)
    isnothing(carrier)            || (body["carrier"]           = carrier)
    isnothing(consider_ip)        || (body["considerIp"]        = consider_ip)
    isnothing(cell_towers)        || (body["cellTowers"]        = cell_towers)
    isnothing(wifi_access_points) || (body["wifiAccessPoints"]  = wifi_access_points)

    _request(c, GEOLOCATION_PATH;
             method = :POST,
             json_body = body,
             base_url = GEOLOCATION_BASE_URL,
             accepts_clientid = false,
             extract_body = _geolocation_extract)
end

# Geolocation returns 404 "notFound" as a valid body (not an error), and uses
# AIP-style `error.errors[].reason` rather than the legacy `status` envelope.
function _geolocation_extract(resp)
    body = JSON.parse(resp.body)
    (resp.status == 200 || resp.status == 404) && return body
    # Best-effort reason extraction — shape may vary on transport-level failures.
    err_reason = try
        String(body.error.errors[1].reason)
    catch
        nothing
    end
    if resp.status == 403
        throw(_OverQueryLimit(something(err_reason, "OVER_QUERY_LIMIT"), err_reason))
    end
    throw(ApiError(something(err_reason, "HTTP_$(resp.status)"), err_reason))
end
