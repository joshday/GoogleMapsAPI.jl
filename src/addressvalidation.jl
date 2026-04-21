#-----------------------------------------------------------------------------# Address Validation API
const ADDRESS_VALIDATION_BASE_URL = "https://addressvalidation.googleapis.com"

"""
    addressvalidation(address_lines; region_code=nothing, locality=nothing,
                      enable_usps_cass=false, ...) -> JSON3.Object

Validate a postal address. `address_lines` is a string (wrapped to a
one-element vector) or a vector of address-line strings. `enable_usps_cass`
is US/PR only.
"""
function addressvalidation(
    address_lines::Union{AbstractString,AbstractVector{<:AbstractString}};
    region_code::Union{Nothing,AbstractString} = nothing,
    locality::Union{Nothing,AbstractString} = nothing,
    enable_usps_cass::Bool = false,
    client::Union{Nothing,GoogleMapsClient} = nothing,
    key::Union{Nothing,AbstractString} = nothing,
    timeout::Union{Nothing,Real} = nothing,
)
    c = _client_from_kwargs(; client, key, timeout)
    lines = address_lines isa AbstractString ? [String(address_lines)] :
            [String(l) for l in address_lines]
    address = Dict{String,Any}("addressLines" => lines)
    region_code === nothing || (address["regionCode"] = region_code)
    locality    === nothing || (address["locality"]   = locality)
    body = Dict{String,Any}("address" => address)
    enable_usps_cass && (body["enableUspsCass"] = true)

    _request(c, "/v1:validateAddress";
             method = :POST,
             json_body = body,
             base_url = ADDRESS_VALIDATION_BASE_URL,
             accepts_clientid = false,
             extract_body = _addressvalidation_extract)
end

# Address Validation uses the AIP error envelope (no legacy `status` field),
# so the caller inspects `body.result` / `body.error` directly.
_addressvalidation_extract(resp) = JSON3.read(resp.body)
