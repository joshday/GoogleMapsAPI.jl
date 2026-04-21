module GoogleMapsAPIGeoInterfaceExt

using GeoInterface
using GoogleMapsAPI: GMPoint, GMLineString, GMFeature, GMFeatureCollection

#-----------------------------------------------------------------------------# trait dispatch
GeoInterface.isgeometry(::Type{GMPoint})       = true
GeoInterface.isgeometry(::Type{GMLineString})  = true
GeoInterface.geomtrait(::GMPoint)              = PointTrait()
GeoInterface.geomtrait(::GMLineString)         = LineStringTrait()

GeoInterface.trait(::GMFeature)                = FeatureTrait()
GeoInterface.trait(::GMFeatureCollection)      = FeatureCollectionTrait()
GeoInterface.isfeature(::Type{<:GMFeature})    = true
GeoInterface.isfeaturecollection(::Type{GMFeatureCollection}) = true

#-----------------------------------------------------------------------------# Point
# GeoInterface follows (x, y) = (lng, lat) convention.
GeoInterface.ncoord(::PointTrait, ::GMPoint)   = 2
GeoInterface.getcoord(::PointTrait, p::GMPoint, i::Integer) =
    i == 1 ? p.lng :
    i == 2 ? p.lat :
    throw(BoundsError(p, i))
GeoInterface.x(::PointTrait, p::GMPoint)       = p.lng
GeoInterface.y(::PointTrait, p::GMPoint)       = p.lat

#-----------------------------------------------------------------------------# LineString
GeoInterface.ncoord(::LineStringTrait, ls::GMLineString) =
    isempty(ls.points) ? 2 : GeoInterface.ncoord(PointTrait(), ls.points[1])
GeoInterface.ngeom(::LineStringTrait, ls::GMLineString) = length(ls.points)
GeoInterface.getgeom(::LineStringTrait, ls::GMLineString, i::Integer) = ls.points[i]

#-----------------------------------------------------------------------------# Feature
# `geometry` and `properties` don't dispatch through `trait`; define 1-arg forms.
GeoInterface.geometry(f::GMFeature)   = f.geometry
GeoInterface.properties(f::GMFeature) = f.properties

#-----------------------------------------------------------------------------# FeatureCollection
GeoInterface.nfeature(::FeatureCollectionTrait, fc::GMFeatureCollection) = length(fc)
GeoInterface.getfeature(::FeatureCollectionTrait, fc::GMFeatureCollection, i::Integer) =
    fc.features[i]

end # module
