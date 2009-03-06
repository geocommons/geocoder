require 'rubygems'
require 'geo_ruby'
require 'zip/zip'
require 'tmpdir'
require 'find'
require 'us/database'

module Geocoder::US
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
    class << self
      def suffix (value)
        @suffix = value
      end
      def file (prefix, extension)
        prefix + "_" + @suffix.to_s + "." + extension
      end
      def map (fields)
        @field_map ||= {}
        @field_map.merge! fields
      end
      def field (name)
        @field_map ||= {}
        name = name.downcase.to_sym
        @field_map[name] || name
      end
      def target (cls)
        @target = cls
      end
      def target_class
        @target
      end
    end
    def initialize (filename, cache=nil)
      cache = Cache.new() if cache.nil?
      @shp = GeoRuby::Shp4r::ShpFile.open self.class.file(filename, "shp")
      @cache = cache
    end
    def each
      @shp.each {|record| yield record}
    end
    def process_each 
      each {|record| yield process convert(record) if use? record.data}
    end
    def use? (data)
      true
    end
    def convert (record)
      data = {:geometry => record.geometry}
      record.data.each {|k,v| data[self.class.field(k)] ||= v}
      data
    end
    def process (data)
      self.class.target_class.new(data)
    end
  end

  class Dbf < Shp
    def initialize (filename, cache=nil)
      cache = Cache.new() if cache.nil?
      @dbf = GeoRuby::Shp4r::Dbf::Reader.open self.class.file(filename, "dbf")
      @cache = cache
    end
    def record (idx)
      @dbf.record(idx)
    end
    def each
      for i in 0 ... @dbf.record_count
        yield GeoRuby::Shp4r::ShpRecord.new(nil,record(i))
      end
    end
  end

  class CurrentPlaces < Dbf
    suffix :place
    target Place
  end

  class AllLines < Shp
    suffix :edges
    target Edge
    def use? (data)
      data["MTFCC"].start_with? "S" and data["FULLNAME"].any?
    end
    def process_place (data)
      @cache.line2place[data[:tlid]] = [
        @cache.face2place[data[:tfidl]], 
        @cache.face2place[data[:tfidr]]
      ]
      @cache.line2zip[data[:tlid]] = [
        data[:zipl],
        data[:zipr]  
      ] 
      Edge.new(data)
    end
  end

  class AddressRanges < Dbf
    suffix :addr
    target Range
  end

  class FeatureNames < Dbf
    suffix :featnames
    target Feature
    map :predirabrv => :predir
    map :pretypabrv => :pretyp
    map :prequalabr => :prequal
    map :sufdirabrv => :sufdir
    map :suftypabrv => :suftyp
    map :sufqualabr => :sufqual
    def use? (data)
      data["MTFCC"].start_with? "S" and data["NAME"].any?
    end
    def process_places (record)
      tlid = record[:tlid]
      locales = []
      for place in cache.line2place[tlid]
        for zip in cache.line2zip[tlid]
          locales << [place,zip]
        end
      end
      locales.uniq!
      for place, zip in locales
        result = record.dclone
        result[:place] = place
        result[:zip] = zip
        results << Feature.new(result)
      end
      results
    end
  end 

  class TopoFaces < Dbf
    suffix :faces
    def process (data)
      []
    end
  end

  class State
    def initialize (path)
      @path = path
    end
    def import_file (cls, db)
      glob = cls.file("#{@path}/*", "zip")
      archive, = Dir[glob]
      throw "can't find ZIP file #{glob}" if archive.nil?
      Dir.mktmpdir {|dir|
        Zip::ZipFile::open(archive) { |zf|
           zf.each {|file| zf.extract(file, File.join(dir, file.name)) }
        } 
        archive[/_[a-z]+\.zip$/] = ""
        extracted = File.join(dir, File.basename(archive))
        source = cls.new(extracted, @cache)
        source.process_each {|records|
          records = [records] unless records.is_a? Array
          records.each {|record| db.insert(record)}
        }
      }
    end
    def import (db)
      puts "importing places from " + @path
      # db.transact { import_file(CurrentPlaces, db) }
      Find.find(@path) {|dir|
        County.new(dir).import(db) if dir != @path and File.directory? dir
      }
    end
  end

  class County < State
    def initialize (path)
      @path = path
      @cache = Cache.new()
    end
    def import (db)
      puts "importing " + @path
      #db.transact {
        #for cls in [TopoFaces, AddressRanges, AllLines, FeatureNames]
      db.transaction
        for cls in [AddressRanges, AllLines, FeatureNames]
          puts "  loading " + cls.name
          import_file(cls, db)
        end
      db.commit
      #}
    end
  end
end
