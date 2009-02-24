require 'sqlite3'
require 'geo_ruby'

module Geocoder
end

module Geocoder::US
  class Table
    def initialize (db)
      @db = db
    end

    def create
      table = self.class.to_s.sub(/.*:/,"").downcase
      columns = fields.map {|k,v| k + " " + v}.join ",\n    "
      sql = "CREATE TABLE #{table} (\n    #{columns});\n"
      for idx in indexes
        idxname = table + "_"+ idx.gsub(/\W/,"_") + "_idx"
        sql += "CREATE INDEX #{idxname} ON #{table} (#{idx});\n"
      end
      puts sql
      @db.execute_batch(sql)
    end

    def fields
      []
    end

    def indexes
      []
    end
  end

  class Places < Table
    def fields
      {
        "plcidfp"     => "INTEGER(7) PRIMARY KEY",
        "name"        => "VARCHAR(100)",
        "name_phone"  => "VARCHAR(100)",
        "name_full"   => "VARCHAR(100)"
      }
    end

    def indexes
      ["name"]
    end
  end

  class Edges < Table
    def fields
      {
        "tlid" => "INTEGER(10) PRIMARY KEY",
        "lfromadd" => "INTEGER(6)",     # From House # (left side)
        "ltoadd" => "INTEGER(6)",     # To House #   (left side)
        "rfromadd" => "INTEGER(6)",     # From House # (right side)
        "rtoadd" => "INTEGER(6)",     # To House #   (right side)
        "geometry" => "BLOB"
      }
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
  end

  class Ranges < Table
    def fields
      {
        "tlid" => "INTEGER(10)",    # TIGER/Line ID
        "fromhn" => "INTEGER(6)",     # From House #
        "tohn" => "INTEGER(6)",     # To House #
        "prefix" => "VARCHAR(12)",    # House number prefix
        "zip" => "INTEGER(5)",     # ZIP code
        "plus4" => "INTEGER(5)",     # ZIP plus 4
        "side" => "CHAR(1)",        # Side flag 
        "fromtyp" => "CHAR(1)",        # From address range end type
        "totyp" => "CHAR(1)"         # To address range end type
      }
    end
    def indexes
      ["tlid"]
    end
  end

  class Tiger
    def initialize (filename)
      @shp = GeoRuby::Shp4r::ShpFile(filename)
    end
  end

  class AllLines < Tiger
    def fields
      []
    end
  end

  def self.open_db(filename)
    SQLite3::Database.new( filename )
  end

  def self.create_all(filename)
    db = self.open_db(filename)
    for cls_name in self.constants
      cls = self.const_get(cls_name)
      if cls.superclass == Geocoder::US::Table
        table = cls.new(db) 
        table.create unless table.fields.empty?
      end
    end
    db.close
  end

  
end
