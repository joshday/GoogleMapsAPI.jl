# GoogleMapsAPI.jl

A Julia wrapper for the [Google Maps Platform](https://developers.google.com/maps)
web APIs with feature parity to the official
[`googlemaps`](https://github.com/googlemaps/google-maps-services-python)
Python client.

Coverage:

- **Routes API** — `compute_routes`, `compute_route_matrix`
- **Geocoding API** — `geocode`, `reverse_geocode`
- **Elevation API** — `elevation`, `elevation_along_path`
- **Geolocation API** — `geolocate`
- **Time Zone API** — `timezone`
- **Roads API** — `snap_to_roads`, `nearest_roads`, `speed_limits`, `snapped_speed_limits`
- **Places API (legacy)** — `find_place`, `places`, `places_nearby`, `place`,
  `places_photo`, `places_autocomplete`, `places_autocomplete_query`
- **Maps Static API** — `static_map`
- **Address Validation API** — `addressvalidation`
- **Utilities** — `encode_polyline`, `decode_polyline`, `waypoint`,
  `parse_duration`
- **Client infrastructure** — `GoogleMapsClient` with retry-with-jittered-backoff
  on 5xx + `OVER_QUERY_LIMIT`, QPS/QPM rate-limiting, HMAC-SHA1 URL signing
  for enterprise `client_id`/`client_secret` credentials, and the
  `X-Goog-Maps-Experience-ID` header.

## Installation

```julia
using Pkg
Pkg.add(url = "https://github.com/joshday/GoogleMapsAPI.jl")
```

## Authentication

Every function reads `ENV["GOOGLE_MAPS_API_KEY"]` by default. Override with
`key = "..."`, or pass a preconfigured `client = GoogleMapsClient(...)`.

```sh
export GOOGLE_MAPS_API_KEY="your-key-here"
```

## Client options

The flat-function surface (`geocode("...")`, `elevation([...])`, etc.) is the
simplest path for one-off calls. For longer-running scripts, construct a
`GoogleMapsClient` once and reuse it — this preserves the rate-limiter window
across calls and lets you configure retries, the experience-id header, or
enterprise signing in one place:

```julia
c = GoogleMapsClient(
    key                 = ENV["GOOGLE_MAPS_API_KEY"],
    timeout             = 30,
    retry_timeout       = 60,
    queries_per_second  = 60,
    queries_per_minute  = 6000,
    retry_over_query_limit = true,
    experience_id       = "my-analytics-id",   # optional X-Goog-Maps-Experience-ID header
)

geocode("1600 Amphitheatre Pkwy, Mountain View, CA"; client = c)
elevation((27.9881, 86.9250); client = c)
```

Per-call overrides (`key=`, `timeout=`) do **not** mutate the shared client;
they share the rate-limit state so throttling continues to work.

Enterprise signing uses `client_id` + `client_secret`:

```julia
c = GoogleMapsClient(client_id = "gme-myorg",
                     client_secret = "vNIXE0xscrmjlyV-12Nj_BvUPaw=")
```

## Routes API

```julia
r = compute_routes(
    (35.9132, -79.0822),                         # Carrboro, NC
    (38.9805, -77.0915);                         # Bethesda, MD
    routing_preference = "TRAFFIC_AWARE_OPTIMAL",
    departure_time     = "2026-04-27T08:00:00-04:00",
    traffic_model      = "BEST_GUESS",
)
parse_duration(r.routes[1].duration)   # seconds
r.routes[1].distanceMeters             # meters
```

Matrix:

```julia
m = compute_route_matrix(
    [(35.9132, -79.0822), "Raleigh, NC"],
    [(38.9805, -77.0915), "New York, NY"];
    routing_preference = "TRAFFIC_AWARE",
)
for el in m
    println(el.originIndex, " → ", el.destinationIndex,
            ": ", parse_duration(el.duration), "s, ",
            el.distanceMeters, "m")
end
```

## Geocoding API

```julia
r = geocode("1600 Amphitheatre Pkwy, Mountain View, CA")
r.results[1].geometry.location       # (lat, lng)

rev = reverse_geocode(37.4220, -122.0841)
rev.results[1].formatted_address
```

## Elevation API

```julia
# Single point elevation
elevation((27.9881, 86.9250))[1].elevation   # ≈ 8848m, Mt Everest

# Sampled along a path
elevation_along_path([(36.578, -118.292), (36.23, -116.83)], 10)
```

## Geolocation API

```julia
geolocate(consider_ip = true)
```

## Time Zone API

```julia
tz = timezone((39.6034, -119.6822); timestamp = 1331161200)
tz.timeZoneId       # "America/Los_Angeles"
tz.rawOffset        # -28800
```

## Roads API

```julia
snap_to_roads([(60.170880, 24.942795), (60.170879, 24.942796)])
nearest_roads([(60.170880, 24.942795)])
speed_limits(["ChIJ...place_id1", "ChIJ...place_id2"])
snapped_speed_limits([(60.170880, 24.942795), (60.170879, 24.942796)])
```

## Places API (legacy)

```julia
places("coffee"; location = (37.7749, -122.4194), radius = 500)
places_nearby(; location = (37.7749, -122.4194), radius = 300, type = "bar")
find_place("pizza", "textquery"; fields = ["name", "place_id", "geometry"])
place("ChIJN1t_tDeuEmsRUsoyG83frY4"; fields = ["name", "formatted_address"])
preds = places_autocomplete("1600 Amphi"; language = "en")

bytes = places_photo("CnRvAAA...photoRef"; max_width = 400)
write("photo.jpg", bytes)
```

## Maps Static API

```julia
bytes = static_map((400, 300);
    center = (40.714728, -73.998672),
    zoom   = 12,
    markers = "color:red|40.714728,-73.998672",
)
write("map.png", bytes)
```

## Address Validation API

```julia
r = addressvalidation(["1600 Amphitheatre Pkwy", "Mountain View, CA 94043"];
                      region_code = "US")
r.result.address.formattedAddress
```

## Polyline utilities

```julia
enc = encode_polyline([(38.5, -120.2), (40.7, -120.95), (43.252, -126.453)])
# "_p~iF~ps|U_ulLnnqC_mqNvxq`@"

pts = decode_polyline(enc)
# [(lat = 38.5, lng = -120.2), (lat = 40.7, lng = -120.95), (lat = 43.252, lng = -126.453)]
```

## Waypoints and addresses

The Routes API accepts multiple waypoint forms:

- `(lat, lon)` tuples, `NamedTuple`s (`:lat/:lon/:lng/:latitude/:longitude`)
- Address strings — `"1600 Amphitheatre Pkwy, Mountain View, CA"`
- Raw `Dict`s for advanced cases (`placeId`, encoded polylines, …)

## Response format

Responses are parsed with [JSON3](https://github.com/quinnj/JSON3.jl) —
navigate them with field access (`r.routes[1].duration`) or as a dict.

## Exceptions

- `ApiError(status, message)` — non-OK status in the response envelope
  (e.g. `"OVER_QUERY_LIMIT"`, `"REQUEST_DENIED"`).
- `HTTPError(status)` — unexpected HTTP status on endpoints without an
  envelope.
- `TransportError(cause)` — network / DNS / unexpected exception.
- `RequestTimeout()` — total elapsed time exceeded `client.retry_timeout`.

## Running tests

Offline (no network):

```sh
julia --project -e 'using Pkg; Pkg.test()'
```

Live API opt-in:

```sh
GOOGLE_MAPS_API_LIVE_TESTS=1 GOOGLE_MAPS_API_KEY=... \
    julia --project -e 'using Pkg; Pkg.test()'
```
