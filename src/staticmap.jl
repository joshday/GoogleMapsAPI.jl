#-----------------------------------------------------------------------------# Maps Static API
# Allowed values for the Static Map `format` and `maptype` query parameters; used for client-side validation.
const _STATIC_MAP_IMAGE_FORMATS = ("png8", "png", "png32", "gif", "jpg", "jpg-baseline")
const _STATIC_MAP_TYPES = ("roadmap", "satellite", "terrain", "hybrid")

"""
    static_map(size; kwargs...) -> Vector{UInt8}

Download a static map image. `size` is an int (square) or `(width, height)`.
Either `markers` must be provided OR both `center` and `zoom` must be set.

`markers` / `path` / `visible` / `style` accept either a pre-joined string or
a vector of pipe-joinable parts. See the Google Static Maps docs for the
full list of supported options.
"""
function static_map(
    sz;
    center = nothing,
    zoom::Union{Nothing,Int} = nothing,
    scale::Union{Nothing,Int} = nothing,
    format::Union{Nothing,AbstractString} = nothing,
    maptype::Union{Nothing,AbstractString} = nothing,
    language::Union{Nothing,AbstractString} = nothing,
    region::Union{Nothing,AbstractString} = nothing,
    markers = nothing,
    path = nothing,
    visible = nothing,
    style = nothing,
    client::Union{Nothing,GoogleMapsClient} = nothing,
    key::Union{Nothing,AbstractString} = nothing,
    timeout::Union{Nothing,Real} = nothing,
)
    if isnothing(markers) && (isnothing(center) || isnothing(zoom))
        throw(ArgumentError("static_map requires `markers=` or both `center=` and `zoom=`"))
    end
    if !isnothing(format) && !(format in _STATIC_MAP_IMAGE_FORMATS)
        throw(ArgumentError("invalid format '$format' (expected one of $(_STATIC_MAP_IMAGE_FORMATS))"))
    end
    if !isnothing(maptype) && !(maptype in _STATIC_MAP_TYPES)
        throw(ArgumentError("invalid maptype '$maptype' (expected one of $(_STATIC_MAP_TYPES))"))
    end

    c = _client_from_kwargs(; client, key, timeout)
    params = Pair{String,Any}["size" => size_param(sz)]
    isnothing(center) || push!(params, "center"   => latlng(center))
    isnothing(zoom) || push!(params, "zoom"     => zoom)
    isnothing(scale) || push!(params, "scale"    => scale)
    isnothing(format) || push!(params, "format"   => format)
    isnothing(maptype) || push!(params, "maptype"  => maptype)
    isnothing(language) || push!(params, "language" => language)
    isnothing(region) || push!(params, "region"   => region)
    isnothing(markers) || push!(params, "markers"  => _pipe_or_string(markers))
    isnothing(path) || push!(params, "path"     => _pipe_or_string(path))
    isnothing(visible) || push!(params, "visible"  => location_list(visible))
    isnothing(style) || push!(params, "style"    => _pipe_or_string(style))

    _request(c, "/maps/api/staticmap"; params, extract_body = _bytes_extract)
end

# Accept a `markers=`/`path=`/`style=` value either as a pre-joined string or as a vector of pipe-parts.
_pipe_or_string(s::AbstractString) = String(s)
_pipe_or_string(v) = join_list("|", v)
