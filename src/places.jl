#-----------------------------------------------------------------------------# Places (legacy)
const _PLACES_LOCATION_BIAS_PREFIXES = ("ipbias", "point", "circle", "rectangle")

"""
    find_place(input, input_type; fields=nothing, location_bias=nothing, language=nothing, kwargs...) -> JSON3.Object

Find a place by text input. `input_type` must be `"textquery"` or
`"phonenumber"`.
"""
function find_place(input::AbstractString, input_type::AbstractString;
                    fields::Union{Nothing,AbstractVector} = nothing,
                    location_bias::Union{Nothing,AbstractString} = nothing,
                    language::Union{Nothing,AbstractString} = nothing,
                    client::Union{Nothing,GoogleMapsClient} = nothing,
                    key::Union{Nothing,AbstractString} = nothing,
                    timeout::Union{Nothing,Real} = nothing)
    if input_type != "textquery" && input_type != "phonenumber"
        throw(ArgumentError("input_type must be 'textquery' or 'phonenumber', got '$input_type'"))
    end
    c = _client_from_kwargs(; client, key, timeout)
    params = Pair{String,Any}["input" => input, "inputtype" => input_type]
    if fields !== nothing
        push!(params, "fields" => join_list(",", fields))
    end
    if location_bias !== nothing
        prefix = split(location_bias, ":")[1]
        prefix in _PLACES_LOCATION_BIAS_PREFIXES ||
            throw(ArgumentError("location_bias must start with one of $(_PLACES_LOCATION_BIAS_PREFIXES)"))
        push!(params, "locationbias" => location_bias)
    end
    language === nothing || push!(params, "language" => language)
    _request(c, "/maps/api/place/findplacefromtext/json"; params)
end

"""
    places(; query=nothing, location=nothing, radius=nothing, ...) -> JSON3.Object

Text-search for places.
"""
function places(query::Union{Nothing,AbstractString} = nothing;
                location = nothing, radius::Union{Nothing,Real} = nothing,
                language::Union{Nothing,AbstractString} = nothing,
                min_price::Union{Nothing,Int} = nothing,
                max_price::Union{Nothing,Int} = nothing,
                open_now::Bool = false,
                type::Union{Nothing,AbstractString} = nothing,
                region::Union{Nothing,AbstractString} = nothing,
                page_token::Union{Nothing,AbstractString} = nothing,
                client::Union{Nothing,GoogleMapsClient} = nothing,
                key::Union{Nothing,AbstractString} = nothing,
                timeout::Union{Nothing,Real} = nothing)
    c = _client_from_kwargs(; client, key, timeout)
    _places_search(c, "text"; query, location, radius, language,
                   min_price, max_price, open_now, type, region,
                   keyword=nothing, name=nothing, rank_by=nothing, page_token)
end

"""
    places_nearby(; location=nothing, radius=nothing, ...) -> JSON3.Object

Nearby-search for places. Either `location` or `page_token` is required.
"""
function places_nearby(; location = nothing,
                         radius::Union{Nothing,Real} = nothing,
                         keyword::Union{Nothing,AbstractString} = nothing,
                         language::Union{Nothing,AbstractString} = nothing,
                         min_price::Union{Nothing,Int} = nothing,
                         max_price::Union{Nothing,Int} = nothing,
                         name = nothing,
                         open_now::Bool = false,
                         rank_by::Union{Nothing,AbstractString} = nothing,
                         type::Union{Nothing,AbstractString} = nothing,
                         page_token::Union{Nothing,AbstractString} = nothing,
                         client::Union{Nothing,GoogleMapsClient} = nothing,
                         key::Union{Nothing,AbstractString} = nothing,
                         timeout::Union{Nothing,Real} = nothing)
    location === nothing && page_token === nothing &&
        throw(ArgumentError("either `location` or `page_token` is required"))
    if rank_by == "distance"
        (keyword !== nothing || name !== nothing || type !== nothing) ||
            throw(ArgumentError("rank_by=\"distance\" requires `keyword`, `name`, or `type`"))
        radius === nothing ||
            throw(ArgumentError("`radius` cannot be set when rank_by=\"distance\""))
    end
    c = _client_from_kwargs(; client, key, timeout)
    _places_search(c, "nearby"; query=nothing, location, radius, language,
                   min_price, max_price, open_now, type, region=nothing,
                   keyword, name, rank_by, page_token)
end

function _places_search(c::GoogleMapsClient, url_part::AbstractString;
                        query, location, radius, language, min_price, max_price,
                        open_now, type, region, keyword, name, rank_by, page_token)
    params = Pair{String,Any}[]
    query      === nothing || push!(params, "query"     => query)
    location   === nothing || push!(params, "location"  => latlng(location))
    radius     === nothing || push!(params, "radius"    => radius)
    keyword    === nothing || push!(params, "keyword"   => keyword)
    language   === nothing || push!(params, "language"  => language)
    min_price  === nothing || push!(params, "minprice"  => min_price)
    max_price  === nothing || push!(params, "maxprice"  => max_price)
    name       === nothing || push!(params, "name"      => join_list(" ", name))
    open_now             && push!(params, "opennow"   => "true")
    rank_by    === nothing || push!(params, "rankby"    => rank_by)
    type       === nothing || push!(params, "type"      => type)
    region     === nothing || push!(params, "region"    => region)
    page_token === nothing || push!(params, "pagetoken" => page_token)
    _request(c, "/maps/api/place/$(url_part)search/json"; params)
end

"""
    place(place_id; fields=nothing, language=nothing, ...) -> JSON3.Object

Detailed info for a single place by place_id.
"""
function place(place_id::AbstractString;
               session_token::Union{Nothing,AbstractString} = nothing,
               fields::Union{Nothing,AbstractVector} = nothing,
               language::Union{Nothing,AbstractString} = nothing,
               reviews_no_translations::Bool = false,
               reviews_sort::Union{Nothing,AbstractString} = "most_relevant",
               client::Union{Nothing,GoogleMapsClient} = nothing,
               key::Union{Nothing,AbstractString} = nothing,
               timeout::Union{Nothing,Real} = nothing)
    c = _client_from_kwargs(; client, key, timeout)
    params = Pair{String,Any}["placeid" => place_id]
    fields === nothing || push!(params, "fields" => join_list(",", fields))
    language === nothing || push!(params, "language" => language)
    session_token === nothing || push!(params, "sessiontoken" => session_token)
    reviews_no_translations && push!(params, "reviews_no_translations" => "true")
    reviews_sort === nothing || push!(params, "reviews_sort" => reviews_sort)
    _request(c, "/maps/api/place/details/json"; params)
end

"""
    places_photo(photo_reference; max_width=nothing, max_height=nothing, ...) -> Vector{UInt8}

Download a place photo's raw bytes. At least one of `max_width`/`max_height`
is required.
"""
function places_photo(photo_reference::AbstractString;
                      max_width::Union{Nothing,Int} = nothing,
                      max_height::Union{Nothing,Int} = nothing,
                      client::Union{Nothing,GoogleMapsClient} = nothing,
                      key::Union{Nothing,AbstractString} = nothing,
                      timeout::Union{Nothing,Real} = nothing)
    max_width === nothing && max_height === nothing &&
        throw(ArgumentError("at least one of `max_width` or `max_height` is required"))
    c = _client_from_kwargs(; client, key, timeout)
    params = Pair{String,Any}["photoreference" => photo_reference]
    max_width  === nothing || push!(params, "maxwidth"  => max_width)
    max_height === nothing || push!(params, "maxheight" => max_height)
    _request(c, "/maps/api/place/photo"; params, extract_body = _bytes_extract)
end

"""
    places_autocomplete(input_text; ...) -> Vector (predictions)
"""
function places_autocomplete(input_text::AbstractString;
                             session_token::Union{Nothing,AbstractString} = nothing,
                             offset::Union{Nothing,Int} = nothing,
                             origin = nothing,
                             location = nothing,
                             radius::Union{Nothing,Real} = nothing,
                             language::Union{Nothing,AbstractString} = nothing,
                             types::Union{Nothing,AbstractString} = nothing,
                             components_::Union{Nothing,AbstractDict} = nothing,
                             strict_bounds::Bool = false,
                             client::Union{Nothing,GoogleMapsClient} = nothing,
                             key::Union{Nothing,AbstractString} = nothing,
                             timeout::Union{Nothing,Real} = nothing)
    c = _client_from_kwargs(; client, key, timeout)
    _autocomplete(c, ""; input_text, session_token, offset, origin, location,
                  radius, language, types, components_, strict_bounds)
end

"""
    places_autocomplete_query(input_text; ...) -> Vector (predictions)
"""
function places_autocomplete_query(input_text::AbstractString;
                                   offset::Union{Nothing,Int} = nothing,
                                   location = nothing,
                                   radius::Union{Nothing,Real} = nothing,
                                   language::Union{Nothing,AbstractString} = nothing,
                                   client::Union{Nothing,GoogleMapsClient} = nothing,
                                   key::Union{Nothing,AbstractString} = nothing,
                                   timeout::Union{Nothing,Real} = nothing)
    c = _client_from_kwargs(; client, key, timeout)
    _autocomplete(c, "query"; input_text, session_token=nothing, offset,
                  origin=nothing, location, radius, language, types=nothing,
                  components_=nothing, strict_bounds=false)
end

function _autocomplete(c::GoogleMapsClient, url_part::AbstractString;
                       input_text, session_token, offset, origin, location,
                       radius, language, types, components_, strict_bounds)
    params = Pair{String,Any}["input" => input_text]
    session_token === nothing || push!(params, "sessiontoken" => session_token)
    offset        === nothing || push!(params, "offset"       => offset)
    origin        === nothing || push!(params, "origin"       => latlng(origin))
    location      === nothing || push!(params, "location"     => latlng(location))
    radius        === nothing || push!(params, "radius"       => radius)
    language      === nothing || push!(params, "language"     => language)
    types         === nothing || push!(params, "types"        => types)
    if components_ !== nothing
        if length(components_) != 1 || !(first(keys(components_)) in ("country", :country))
            throw(ArgumentError("autocomplete `components_` may only contain `country`"))
        end
        push!(params, "components" => components(components_))
    end
    strict_bounds && push!(params, "strictbounds" => "true")
    get(_request(c, "/maps/api/place/$(url_part)autocomplete/json"; params),
        :predictions, [])
end
