# Converts tile xyz index to latitude/longitude for our custom projections

require 'rubygems'
require 'pr_geohash'
require 'proj4'

module Fluent
  class TileLocationFilter < Output
    Fluent::Plugin.register_output('tile_location_filter', self)

    config_param :tag, :string, :default => nil
    config_param :tile_x_key, :string, :default => "x"
    config_param :tile_y_key, :string, :default => "y"
    config_param :tile_zoom_key, :string, :default => "zoom"
    config_param :tile_style_key, :string, :default => "style"

    KNOWN_STYLES = {
      "osm_3571" => "epsg:3571",
      "osm_3572" => "epsg:3572",
      "osm_3573" => "epsg:3573",
      "osm_3574" => "epsg:3574",
      "osm_3575" => "epsg:3575",
      "osm_3576" => "epsg:3576"
    }
    # Extent for LAEA 3571-3576
    EXTENT = 20037509.762

    def configure(conf)
      super
    end

    def emit(tag, es, chain)
      es.each { |time, record|
        new_record = add_location(record)
        log.info record
        log.info new_record
        Fluent::Engine.emit(@tag, time, new_record)
      }
      chain.next
    end

    def add_location(record)
      x = record[@tile_x_key].to_i
      y = record[@tile_y_key].to_i
      z = record[@tile_zoom_key].to_i
      style = record[@tile_style_key]

      return record if !KNOWN_STYLES.keys.include?(style)
      proj_x, proj_y = get_tile_centre(x, y, z)
      lon, lat = reproject(proj_x, proj_y, KNOWN_STYLES[style])

      record["location"] = {
        "lat" => lat,
        "lon" => lon,
        "geohash" => GeoHash.encode(lat, lon)
      }
      record[@tile_x_key] = x
      record[@tile_y_key] = y
      record[@tile_zoom_key] = z
      record
    end

    def get_tile_centre(x, y, z)
      px = EXTENT * (2 * x - ((2 ** z) - 1)) / (2 ** z)
      py = EXTENT * (((2 ** z) - 1) - 2 * y) / (2 ** z)
      [px, py]
    end

    def reproject(x, y, source)
      proj = Proj4::Projection.new(["init=#{source}"])
      wgs84 = proj.inverse(Proj4::Point.new(x, y))
      [r2d(wgs84.lon), r2d(wgs84.lat)]
    end

    def r2d(rad)
       180 * rad / Math::PI
    end
  end
end
