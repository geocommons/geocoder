require 'rubygems'
require 'geo_ruby'

module Geocoder
end

module Geocoder::US
  module Tiger
    class Cache
      attr :face2place
      attr :line2place
      attr :line2zip
      attr :tlids
  
      def reset!
        @face2place = {}
        @line2place = {}
        @line2zip   = {}
        @tlids      = {}
      end
      
      alias initialize reset!
    end

    class Shp
      attr :cache
      def initialize (filename, cache=nil)
        cache = Cache.new() if cache.nil?
        @shp = GeoRuby::Shp4r::ShpFile.open(filename + "_" + suffix)
        @cache = cache
      end
      def each
        @shp.each {|record| 
          add_to_cache record.data
          yield record
        }
      end
      def add_to_cache (record)
      end
    end

    class Dbf < Shp
      def initialize (filename, cache=nil)
        cache = Cache.new() if cache.nil?
        filename += "_" + suffix + ".dbf"
        @dbf = GeoRuby::Shp4r::Dbf::Reader.open(filename)
        @cache = cache
      end
      def record (idx)
        @dbf.record(idx)
      end
      def each
        for i in 0 ... @dbf.record_count
          record = @dbf.record(i)
          add_to_cache record
          yield GeoRuby::Shp4r::ShpRecord.new(nil,record)
        end
      end
    end

    class CurrentPlaces < Dbf
      def suffix
        "place"
      end    
    end

    class AllLines < Shp
      def suffix
        "edges"
      end
      def add_to_cache(record)
        @cache.line2place[record["TLID"]] = [
          @cache.face2place[record["TFIDL"]], 
          @cache.face2place[record["TFIDR"]]
        ]
        @cache.line2zip[record["TLID"]] = [
          record["ZIPL"],
          record["ZIPR"]  
        ] 
      end
    end

    class AddressRanges < Dbf
      def suffix
        "addr"
      end
      def add_to_cache(record)
        @cache.tlids[record["TLID"]] = true
      end
    end

    class FeatureNames < Dbf
      def suffix
        "featnames"
      end
    end 

    class TopoFaces < Dbf
      def suffix
        "faces"
      end
      def add_to_cache(record)
        @cache.face2place[record["TFID"]] = record["STATEFP"]+record["PLACEFP"]
      end
    end

    class County
      def initialize (filename)
        @filename = filename
        @cache = Cache.new()
      end
      def import (db)
        puts "importing " + @filename
        for cls in [TopoFaces, AddressRanges, AllLines, FeatureNames]
          puts "  loading " + cls.name
          source = cls.new(@filename, @cache)
          db.import_all(source)
        end
      end
    end
  end
end
