#-----------------------------------------------------------------------------# Maps Static API
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
    if markers === nothing && (center === nothing || zoom === nothing)
        throw(ArgumentError("static_map requires `markers=` or both `center=` and `zoom=`"))
    end
    if format !== nothing && !(format in _STATIC_MAP_IMAGE_FORMATS)
        throw(ArgumentError("invalid format '$format' (expected one of $(_STATIC_MAP_IMAGE_FORMATS))"))
    end
    if maptype !== nothing && !(maptype in _STATIC_MAP_TYPES)
        throw(ArgumentError("invalid maptype '$maptype' (expected one of $(_STATIC_MAP_TYPES))"))
    end

    c = _client_from_kwargs(; client, key, timeout)
    params = Pair{String,Any}["size" => size_param(sz)]
    center  === nothing || push!(params, "center"   => latlng(center))
    zoom    === nothing || push!(params, "zoom"     => zoom)
    scale   === nothing || push!(params, "scale"    => scale)
    format  === nothing || push!(params, "format"   => format)
    maptype === nothing || push!(params, "maptype"  => maptype)
    language === nothing || push!(params, "language" => language)
    region  === nothing || push!(params, "region"   => region)
    markers === nothing || push!(params, "markers"  => _pipe_or_string(markers))
    path    === nothing || push!(params, "path"     => _pipe_or_string(path))
    visible === nothing || push!(params, "visible"  => location_list(visible))
    style   === nothing || push!(params, "style"    => _pipe_or_string(style))

    _request(c, "/maps/api/staticmap"; params, extract_body = _bytes_extract)
end

_pipe_or_string(s::AbstractString) = String(s)
_pipe_or_string(v) = join_list("|", v)
