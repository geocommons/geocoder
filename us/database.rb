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
      @tables = table_classes
    end

    def table_classes
      table_module = Geocoder::US
      table_class  = table_module.const_get("Table")
      table_module.constants.map {|cname| table_module.const_get(cname)} \
                       .find_all {|cls| cls.superclass == table_class}
    end

    def prepare_inserts
      Hash[@tables.map {|t| [t,@db.prepare(t.insert)]}];
    end

    def insert (record)
      @insert[record.class].execute(record.values)
    end

    def transact
      @insert = prepare_inserts
      @db.transaction { yield }
    end

    def create_all
      @tables.each {|t| @db.execute_batch(t.create)}
    end
    
    def index_all
      @tables.each {|t| @db.execute_batch(t.create_index)}
    end

    def close
      @db.close
    end
  end

  class Table
    class << self
      def field (name, type="VARCHAR(255)",idx=false)
        @fields ||= []
        @fields << name
        @types ||= []
        @types << type
        index name if idx
        send :attr, name, true
      end
      def fields
        @fields
      end
      def index (name)
        @indexes ||= []
        @indexes << name
      end
      def table
        @table ||= name.sub(/.*:/,"").downcase
      end
      def create
        columns = fields.zip(@types).map {|k,v| k.to_s+" "+v}.join ",\n  "
        "CREATE TABLE #{table} (\n  #{columns});\n"
      end
      def create_index
        sql = ""
        for idx in @indexes
          idxname = table + "_"+ idx.to_s.gsub(",","_") + "_idx"
          sql += "CREATE INDEX #{idxname} ON #{table} (#{idx});\n"
        end
        sql
      end
      def insert
        columns = fields.map {|f| f.to_s}.join(",")
        places  = (["?"] * fields.length).join(",")
        "INSERT INTO #{table} (#{columns}) VALUES (#{places});"
      end
    end
    def initialize (data={})
      for field in self.class.fields
        self.send((field.to_s+"=").to_sym, data[field])
      end
    end
    def values
      self.class.fields.map {|f| self.send f}
    end
    def set_name (value)
      @name_phone = Text::Metaphone.metaphone(value)
      @name = value
    end
  end

  class Edge < Table
    # ordinarily tlid is unique, but edges can be duplicated across counties
    # where a road forms part of a county border. it'll slow the import process
    # to have to check each one before inserting, and it'll be even slower
    # to have to do the inserts outside a transaction where the duplicate pkey
    # exception can be caught...
    #
    # field :tlid, "INTEGER(10) PRIMARY KEY", true # TIGER/Line ID
    field :tlid, "INTEGER(10)", true # TIGER/Line ID
    field :geometry, "BLOB"

    def geometry=(value)
      @geometry = SQLite3::Blob.new(value.as_wkb)
    end
  end

  class Feature < Table
    field :tlid, "INTEGER(10)", true    # TIGER/Line ID
    field :name, "VARCHAR(100)", true   # Base portion of name
    field :name_phone, "VARCHAR(100)", true  # Metaphone hash of name
    field :predir, "VARCHAR(2)"       # Prefix direction component
    field :pretyp, "VARCHAR(3)"       # Prefix type component
    field :prequal, "VARCHAR(2)"      # Prefix qualifier component
    field :sufdir, "VARCHAR(2)"       # Suffix direction component
    field :suftyp, "VARCHAR(3)"       # Suffix type component
    field :sufqual, "VARCHAR(2)"      # Suffix qualifier component
    field :paflag, "BOOLEAN"          # Primary/Alternate flag
    field :zip, "INTEGER(5)", true    # ZIP code
    alias name= set_name 
  end

  class Range < Table
    field :tlid, "INTEGER(10)", true    # TIGER/Line ID
    field :fromhn, "INTEGER(6)"         # From House #
    field :tohn, "INTEGER(6)"           # To House #
    field :prefix, "VARCHAR(12)"        # House number prefix
    field :zip, "INTEGER(5)", true      # ZIP code
    field :side, "CHAR(1)"              # Side flag 
  end
end
