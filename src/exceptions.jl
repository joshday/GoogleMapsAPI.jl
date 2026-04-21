#-----------------------------------------------------------------------------# Exceptions
"""
    ApiError(status, message=nothing)

A Google Maps API call returned a non-success status in the response body
(e.g. `"OVER_QUERY_LIMIT"`, `"INVALID_REQUEST"`).
"""
struct ApiError <: Exception
    status::String
    message::Union{Nothing,String}
end
ApiError(status::AbstractString) = ApiError(String(status), nothing)
ApiError(status::AbstractString, message) =
    ApiError(String(status), message === nothing ? nothing : String(message))

function Base.showerror(io::IO, e::ApiError)
    print(io, "ApiError(", e.status)
    e.message === nothing || print(io, ": ", e.message)
    print(io, ")")
end

"""
    TransportError(cause)

Something went wrong while executing the HTTP request (DNS, connection reset,
etc.). `cause` holds the underlying exception.
"""
struct TransportError <: Exception
    cause::Any
end
Base.showerror(io::IO, e::TransportError) =
    print(io, "TransportError(", e.cause === nothing ? "unknown" : e.cause, ")")

"""
    HTTPError(status)

An unexpected HTTP status was returned (non-200 on an endpoint that doesn't
wrap its errors in the API-status envelope).
"""
struct HTTPError <: Exception
    status::Int
end
Base.showerror(io::IO, e::HTTPError) = print(io, "HTTPError(status=", e.status, ")")

"""
    RequestTimeout()

Total time across attempts exceeded `client.retry_timeout`.
"""
struct RequestTimeout <: Exception end
Base.showerror(io::IO, ::RequestTimeout) = print(io, "RequestTimeout()")

# Module-private retry marker — raised internally by response extractors when
# the server reports an over-quota condition. The public surface never sees
# this type; it is either retried (and consumed) or re-wrapped as `ApiError`.
struct _OverQueryLimit <: Exception
    status::String
    message::Union{Nothing,String}
end
_OverQueryLimit(status::AbstractString) = _OverQueryLimit(String(status), nothing)
_OverQueryLimit(status::AbstractString, message) =
    _OverQueryLimit(String(status), message === nothing ? nothing : String(message))
