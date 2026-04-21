using SHA: hmac_sha1
using Base64: base64encode, base64decode

#-----------------------------------------------------------------------------# signing
_urlsafe_b64decode(s::AbstractString) = base64decode(replace(String(s), '-' => '+', '_' => '/'))
_urlsafe_b64encode(b::AbstractVector{UInt8}) = replace(base64encode(b), '+' => '-', '/' => '_')

"""
    sign_hmac(secret, payload) -> String

Return the base64-URL-safe-encoded HMAC-SHA1 of `payload` keyed by the
base64-URL-safe-decoded `secret`. Used for Google Maps Platform enterprise
request signing (`client_id` / `client_secret` credentials).
"""
function sign_hmac(secret::AbstractString, payload::AbstractString)
    k = _urlsafe_b64decode(secret)
    sig = hmac_sha1(k, Vector{UInt8}(String(payload)))
    _urlsafe_b64encode(sig)
end
