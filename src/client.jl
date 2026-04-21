using HTTP.URIs: escapeuri

# Package version — used in the User-Agent header; falls back for unregistered dev versions.
const _PKG_VERSION = try
    string(pkgversion(@__MODULE__))
catch
    "0.1.0"
end
# Headers + retry config shared across all requests.
const _USER_AGENT = "GoogleMapsAPI.jl/$(_PKG_VERSION)"
const _EXPERIENCE_ID_HEADER = "X-Goog-Maps-Experience-ID"
const _RETRIABLE_STATUSES = (500, 503, 504)

# Default HTTP transport for `GoogleMapsClient.transport`; test stubs follow the same signature.
_default_transport(method::Symbol, url::AbstractString;
                   headers, body, readtimeout, status_exception) =
    HTTP.request(String(method), url;
                 headers = headers, body = body,
                 readtimeout = readtimeout,
                 status_exception = status_exception)

#-----------------------------------------------------------------------------# GoogleMapsClient
"""
    GoogleMapsClient(; key, client_id, client_secret, ...) -> GoogleMapsClient

Container for Google Maps Platform credentials and per-connection options.
Primary use: pass to any flat-function call via `client = ...` instead of
repeating `key=`, `timeout=`, etc.

### Keyword Arguments
- `key`: Maps API key (required unless `client_id` + `client_secret` set).
- `client_id`, `client_secret`: enterprise Maps-for-Work credentials.
  `client_secret` must be the base64-URL-safe-encoded signing secret.
- `channel`: enterprise tracking channel. Alphanumeric `._-` only.
- `timeout`: read timeout per HTTP call (seconds, default 30).
- `retry_timeout`: total time budget across retries (seconds, default 60).
- `queries_per_second`, `queries_per_minute`: rate-limit caps; client
  sleeps to stay under the tighter of the two.
- `retry_over_query_limit`: whether to retry on `OVER_QUERY_LIMIT` /
  Roads `RESOURCE_EXHAUSTED`. Default `true`.
- `experience_id`: value for `X-Goog-Maps-Experience-ID` header.
- `base_url`: default API host (`https://maps.googleapis.com`).
- `transport`, `sleep`: runtime hooks, injectable for tests.
"""
Base.@kwdef mutable struct GoogleMapsClient
    key::Union{Nothing,String}             = nothing
    client_id::Union{Nothing,String}       = nothing
    client_secret::Union{Nothing,String}   = nothing
    channel::Union{Nothing,String}         = nothing
    timeout::Real                          = 30
    retry_timeout::Real                    = 60
    queries_per_second::Union{Nothing,Int} = 60
    queries_per_minute::Union{Nothing,Int} = 6000
    retry_over_query_limit::Bool           = true
    experience_id::Union{Nothing,String}   = nothing
    base_url::String                       = "https://maps.googleapis.com"
    transport::Function                    = _default_transport
    sleep::Function                        = Base.sleep
    sent_times::Vector{Float64}            = Float64[]
    lock::ReentrantLock                    = ReentrantLock()
    function GoogleMapsClient(key, client_id, client_secret, channel, timeout,
                              retry_timeout, queries_per_second,
                              queries_per_minute, retry_over_query_limit,
                              experience_id, base_url, transport, sleep,
                              sent_times, lock)
        c = new(key, client_id, client_secret, channel, timeout,
                retry_timeout, queries_per_second, queries_per_minute,
                retry_over_query_limit, experience_id, base_url,
                transport, sleep, sent_times, lock)
        _validate!(c)
    end
end

# Enforce credential / channel-format invariants on a client; called by the inner ctor and after per-call overrides.
function _validate!(c::GoogleMapsClient)
    if isnothing(c.key) && (isnothing(c.client_id) || isnothing(c.client_secret))
        throw(ArgumentError("GoogleMapsClient needs `key=` or `client_id=`+`client_secret=`."))
    end
    if !isnothing(c.key) && !startswith(c.key, "AIza")
        throw(ArgumentError("Invalid API key (expected 'AIza'-prefixed)."))
    end
    if !isnothing(c.channel) && !occursin(r"^[A-Za-z0-9._-]*$", c.channel)
        throw(ArgumentError("channel must match ^[A-Za-z0-9._-]*\$"))
    end
    c
end

# Effective rate cap: the tighter of queries_per_second and queries_per_minute/60, or `nothing` if both unset.
function _queries_quota(c::GoogleMapsClient)
    qps = c.queries_per_second
    qpm = c.queries_per_minute
    isnothing(qps) && isnothing(qpm) && return nothing
    isnothing(qps) && return floor(Int, qpm / 60)
    isnothing(qpm) && return Int(qps)
    floor(Int, min(Int(qps), qpm / 60))
end

#-----------------------------------------------------------------------------# experience_id
"""
    set_experience_id!(client, id) -> client
    set_experience_id!(client, ids::AbstractVector) -> client

Set the `X-Goog-Maps-Experience-ID` header for subsequent calls. Pass a
vector to send a comma-joined list. Pass `nothing` to clear.
"""
function set_experience_id!(c::GoogleMapsClient, id::Union{Nothing,AbstractString})
    c.experience_id = isnothing(id) ? nothing : String(id)
    c
end
function set_experience_id!(c::GoogleMapsClient, ids::AbstractVector)
    c.experience_id = join(ids, ",")
    c
end

"`get_experience_id(client)` — current experience id or `nothing`."
get_experience_id(c::GoogleMapsClient) = c.experience_id

"`clear_experience_id!(client)` — clear the experience id."
clear_experience_id!(c::GoogleMapsClient) = (c.experience_id = nothing; c)

#-----------------------------------------------------------------------------# _urlencode_params
# Build a URL query string from sorted pairs; expands vector values into repeated keys (e.g. placeId=a&placeId=b).
function _urlencode_params(pairs::AbstractVector{<:Pair})
    parts = String[]
    for (k, v) in pairs
        if v isa AbstractVector && !(v isa AbstractString)
            for item in v
                push!(parts, _encode_pair(k, item))
            end
        else
            push!(parts, _encode_pair(k, v))
        end
    end
    join(parts, "&")
end

# URL-encode a single key=value pair.
_encode_pair(k, v) = "$(_fix_escape(escapeuri(string(k))))=$(_fix_escape(escapeuri(string(v))))"

# Match Python's `urlencode(quote_plus)` + `unquote_unreserved` byte-for-byte:
# `escapeuri` emits `%20` for space (want `+`) and `%7E` for `~` (want `~`).
_fix_escape(s::AbstractString) = replace(s, "%20" => "+", "%7E" => "~")

#-----------------------------------------------------------------------------# _generate_auth_url
# Build the full path + query string, either appending `&signature=...` (enterprise) or `&key=...` (API key).
function _generate_auth_url(c::GoogleMapsClient, path::AbstractString, params, accepts_clientid::Bool)
    sorted = _sorted_params(params)
    if accepts_clientid && !isnothing(c.client_id) && !isnothing(c.client_secret)
        isnothing(c.channel) || push!(sorted, "channel" => c.channel)
        push!(sorted, "client" => c.client_id)
        qs = _urlencode_params(sorted)
        path_q = "$(path)?$(qs)"
        sig = sign_hmac(c.client_secret, path_q)
        return "$(path_q)&signature=$(sig)"
    end
    if !isnothing(c.key)
        push!(sorted, "key" => c.key)
        return "$(path)?$(_urlencode_params(sorted))"
    end
    throw(ArgumentError("Endpoint requires an API key (does not accept enterprise credentials)."))
end

# Produce a fresh Pair vector sorted by key (MergeSort is stable, preserving caller order for duplicate keys).
_sorted_params(d::AbstractDict) = sort!(Pair{String,Any}[string(k) => v for (k, v) in d]; by = first, alg = MergeSort)
_sorted_params(v::AbstractVector{<:Pair}) = sort!(Pair{String,Any}[string(k) => val for (k, val) in v]; by = first, alg = MergeSort)

#-----------------------------------------------------------------------------# _request
# Core HTTP entry point: builds the authed URL, drives retries and QPS bookkeeping, and
# dispatches to either a caller-supplied `extract_body` or `_default_extract`.
function _request(
    c::GoogleMapsClient,
    path::AbstractString;
    method::Symbol                             = :GET,
    params                                     = Pair{String,Any}[],
    json_body::Union{Nothing,AbstractDict}     = nothing,
    base_url::AbstractString                   = c.base_url,
    accepts_clientid::Bool                     = true,
    auth::Symbol                               = :query,
    extra_headers::AbstractVector{<:Pair}      = Pair{String,String}[],
    extract_body::Union{Nothing,Function}      = nothing,
    _first_time::Union{Nothing,Float64}        = nothing,
    _retry_counter::Int                        = 0,
)
    first_time = something(_first_time, time())
    if time() - first_time > c.retry_timeout
        throw(RequestTimeout())
    end
    if _retry_counter > 0
        delay = 0.5 * 1.5^(_retry_counter - 1) * (rand() + 0.5)
        c.sleep(delay)
    end

    url = base_url * _build_path(c, path, params, auth, accepts_clientid)

    headers = Pair{String,String}["User-Agent" => _USER_AGENT]
    isnothing(c.experience_id) || push!(headers, _EXPERIENCE_ID_HEADER => c.experience_id)
    if auth === :header
        isnothing(c.key) && throw(ArgumentError("auth=:header requires client.key"))
        push!(headers, "X-Goog-Api-Key" => c.key)
    end
    for h in extra_headers
        push!(headers, string(first(h)) => string(last(h)))
    end
    isnothing(json_body) || push!(headers, "Content-Type" => "application/json")

    body_bytes = isnothing(json_body) ? UInt8[] : Vector{UInt8}(JSON.json(json_body))

    resp = try
        c.transport(method, url;
                    headers = headers,
                    body = body_bytes,
                    readtimeout = c.timeout,
                    status_exception = false)
    catch e
        if e isa HTTP.Exceptions.TimeoutError || e isa HTTP.Exceptions.ConnectTimeout
            throw(RequestTimeout())
        end
        throw(TransportError(e))
    end

    if resp.status in _RETRIABLE_STATUSES
        return _request(c, path;
                        method, params, json_body, base_url,
                        accepts_clientid, auth, extra_headers, extract_body,
                        _first_time = first_time,
                        _retry_counter = _retry_counter + 1)
    end

    _record_send!(c)

    extractor = something(extract_body, _default_extract)
    try
        return extractor(resp)
    catch e
        if e isa _OverQueryLimit
            if c.retry_over_query_limit
                return _request(c, path;
                                method, params, json_body, base_url,
                                accepts_clientid, auth, extra_headers, extract_body,
                                _first_time = first_time,
                                _retry_counter = _retry_counter + 1)
            else
                throw(ApiError(e.status, e.message))
            end
        end
        rethrow(e)
    end
end

# Body extractor for binary endpoints (static_map, places_photo) — returns the raw response bytes.
_bytes_extract(resp) = Vector{UInt8}(resp.body)

# Build the URL suffix (path + query) for a request, branching on auth mode:
# `:query` uses `_generate_auth_url`; `:header` / `:none` omit credentials from the URL.
function _build_path(c::GoogleMapsClient, path, params, auth::Symbol, accepts_clientid::Bool)
    if auth === :query
        return _generate_auth_url(c, path, params, accepts_clientid)
    end
    sorted = _sorted_params(params)
    isempty(sorted) ? String(path) : "$(path)?$(_urlencode_params(sorted))"
end

# QPS bookkeeping: record this send in the rolling-window deque and, if we're at quota,
# compute how long to sleep to stay under the per-second cap.
function _record_send!(c::GoogleMapsClient)
    quota = _queries_quota(c)
    isnothing(quota) && return
    # Reserve a slot under the lock, then sleep outside so concurrent callers
    # don't serialize on each other's 1-second naps.
    wait_for = lock(c.lock) do
        now = time()
        if length(c.sent_times) >= quota
            elapsed = now - c.sent_times[1]
            popfirst!(c.sent_times)
            if elapsed < 1
                slot = now + (1 - elapsed)
                push!(c.sent_times, slot)
                return 1 - elapsed
            end
        end
        push!(c.sent_times, now)
        return 0.0
    end
    wait_for > 0 && c.sleep(wait_for)
end

#-----------------------------------------------------------------------------# default body extractor
# Default body handler for Maps-API endpoints that wrap results in a `status` envelope:
# passes through `OK`/`ZERO_RESULTS`, raises `_OverQueryLimit` on throttling, `ApiError` otherwise.
function _default_extract(resp)
    if resp.status != 200
        throw(HTTPError(resp.status))
    end
    body = JSON.parse(resp.body)
    status = _body_status(body)
    isnothing(status) && return body
    if status == "OK" || status == "ZERO_RESULTS"
        return body
    end
    msg = _body_error_message(body)
    if status == "OVER_QUERY_LIMIT"
        throw(_OverQueryLimit(status, msg))
    end
    throw(ApiError(status, msg))
end

# Pull the `status` string from a response body, or `nothing` if the endpoint returns no envelope.
_body_status(body) = haskey(body, :status) ? String(body.status) : nothing
# Pull the `error_message` string from a response body, if present.
_body_error_message(body) =
    haskey(body, :error_message) ? String(body.error_message) : nothing

#-----------------------------------------------------------------------------# _client_from_kwargs
# `sent_times` and `lock` are shared by reference with the original so
# rate-limit bookkeeping continues across per-call override copies.
_shallow_copy_client(c::GoogleMapsClient) =
    GoogleMapsClient(; (f => getfield(c, f) for f in fieldnames(GoogleMapsClient))...)

# Resolve a `GoogleMapsClient` from flat-function kwargs: either the caller's `client=` (shallow-copied
# if overrides are present), or a new client built from `key=`/`timeout=` (falling back to ENV for key).
function _client_from_kwargs(;
    client::Union{Nothing,GoogleMapsClient} = nothing,
    key::Union{Nothing,AbstractString} = nothing,
    timeout::Union{Nothing,Real} = nothing,
    kwargs...,
)
    if !isnothing(client)
        if isnothing(key) && isnothing(timeout) && isempty(kwargs)
            return client
        end
        c = _shallow_copy_client(client)
        !isnothing(key)     && (c.key = String(key))
        !isnothing(timeout) && (c.timeout = timeout)
        for (k, v) in kwargs
            setproperty!(c, k, v)
        end
        return _validate!(c)
    end
    resolved_key = isnothing(key) ? get(ENV, "GOOGLE_MAPS_API_KEY", nothing) : String(key)
    GoogleMapsClient(; key = resolved_key,
                       timeout = something(timeout, 30),
                       kwargs...)
end

