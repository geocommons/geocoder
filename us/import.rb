require 'rubygems'
require 'sqlite3'
require 'geo_ruby'
require 'text'

module Geocoder
end

module Geocoder::US
  class Database
    def initialize (filename)
      @db = SQLite3::Database.new( filename )
      @tables = table_classes.map {|cls| cls.new()}
    end

    def table_classes
      table_module = Tables
      table_class  = table_module.const_get("Table")
      table_module.constants.map {|cname| table_module.const_get(cname)} \
                       .find_all {|cls| cls.superclass == table_class}
    end

    def prepare_inserts
      @inserts = @tables.map {|t| @db.prepare(t.insert)}
    end

    def import (shape, cache)
      prepare_inserts if @inserts.nil?
      @tables.zip(@inserts).each { |table, insert|
        if table.copy? shape.data, cache
          table.munge(shape, cache).each {|row| insert.execute(row)} 
        end
      }
    end

    def import_all (source)
      @db.transaction { source.each {|shape| import(shape, source.cache) } }
    end

    def create_all
      @tables.each {|t| @db.execute_batch(t.create)}
    end

    def close
      @db.close
    end
  end

  module Tables
    class Table
      def initialize
        @table  = self.class.name.sub(/.*:/,"").downcase
        @fields = fields
      end

      def name
        @table
      end

      def create
        columns = @fields.map {|k,v| k + " " + v}.join ",\n    "
        sql = "CREATE TABLE #{@table} (\n    #{columns});\n"
        for idx in indexes
          idxname = @table + "_"+ idx.gsub(/\W/,"_") + "_idx"
          sql += "CREATE INDEX #{idxname} ON #{@table} (#{idx});\n"
        end
        return sql
      end

      def insert
        columns = @fields.keys
        places = columns.map {|col| ":"+col}.join(",")
        "INSERT INTO #{@table} (#{columns.join ","}) VALUES (#{places});"
      end

      def fields
        []
      end

      def indexes
        []
      end

      def munge(record, cache)
        data = @fields.map {|k,v| record.data[k.upcase]}
        [Hash[*@fields.keys.zip(data).flatten]]
      end

      def copy?(record, cache=nil)
        false
      end
    end

    class Places < Table
      def fields
        {
          "plcidfp"     => "INTEGER(7)",
          "name"        => "VARCHAR(100)",
          "name_phone"  => "VARCHAR(100)"
        }
      end

      def indexes
        ["plcidfp", "name", "name_phone"]
      end

      def copy?(data,cache=nil)
        data.key? "PLCIDFP"
      end

      def munge (record, cache)
        results = super(record, cache)
        # sometimes Census Statistical Areas have hyphenated names...
        # if so, we want to split on the hyphen and create multiple records
        # with each piece of the corresponding name.
        for result in results
          result["name_phone"] = Text::Metaphone.metaphone(result["name"])
        end
        results
      end
    end

    class Edges < Table
      def fields
        {
          "tlid" => "INTEGER(10)",
          "lfromadd" => "INTEGER(6)",     # From House # (left side)
          "ltoadd" => "INTEGER(6)",     # To House #   (left side)
          "rfromadd" => "INTEGER(6)",     # From House # (right side)
          "rtoadd" => "INTEGER(6)",     # To House #   (right side)
          "geometry" => "BLOB"
        }
      end

      def indexes
        ["tlid"]
      end

      def copy?(data,cache=nil)
        data.key? "LFROMADD" and cache.tlids.key? data["TLID"]
      end

      def munge(record, cache)
        results = super(record, cache)
        for result in results
          result["geometry"] = SQLite3::Blob.new(record.geometry.as_wkb)
        end
        results
      end
    end

    class Features < Table
      def fields
        {
          "tlid" => "INTEGER(10)",    # TIGER/Line ID
          "name" => "VARCHAR(100)",   # Base portion of name
          "name_phone" => "VARCHAR(100)",   # Metaphone hash of name
          "predir" => "VARCHAR(2)",     # Prefix direction component
          "pretyp" => "VARCHAR(3)",     # Prefix type component
          "prequal" => "VARCHAR(2)",     # Prefix qualifier component
          "sufdir" => "VARCHAR(2)",     # Suffix direction component
          "suftyp" => "VARCHAR(3)",     # Suffix type component
          "sufqual" => "VARCHAR(2)",     # Suffix qualifier component
          "paflag" => "BOOLEAN",        # Primary/Alternate flag
          "place" => "INTEGER(7)",     # FIPS place ID
          "zip" => "INTEGER(5)"      # ZIP code
        }
      end

      def indexes
        ["name"]
      end

      def copy?(data,cache=nil)
        data.key? "LINEARID" and cache.tlids.key? data["TLID"]
      end

      def munge(record, cache)
        records = super(record, cache)
        results  = []
        for record in records
          record["name_phone"] = Text::Metaphone.metaphone(record["name"])
          tlid = record["tlid"]
          locales = []
          for place in cache.line2place[tlid]
            for zip in cache.line2zip[tlid]
              locales << [place,zip]
            end
          end
          locales.uniq!
          for place, zip in locales
            result = record.dclone
            result["place"] = place
            result["zip"] = zip
            results << result
          end
        end
        results
      end
    end

    class Ranges < Table
      def fields
        {
          "tlid" => "INTEGER(10)",    # TIGER/Line ID
          "fromhn" => "INTEGER(6)",   # From House #
          "tohn" => "INTEGER(6)",     # To House #
          "prefix" => "VARCHAR(12)",  # House number prefix
          "zip" => "INTEGER(5)",      # ZIP code
          "side" => "CHAR(1)",        # Side flag 
          "fromtyp" => "CHAR(1)",     # From address range end type
          "totyp" => "CHAR(1)"        # To address range end type
        }
      end
      def indexes
        ["tlid"]
      end
      def copy?(data, cache=nil)
        data.key? "FROMHN"
      end
    end
  end
end
