require 'rubygems'
require 'sqlite3'
require 'geo_ruby'
require 'text'
require 'geocoder/us/address'

module Geocoder::US
  class Database
    def initialize (filename, helper="libsqlite3_geocoder.so")
      @db = SQLite3::Database.new( filename )
      @db.results_as_hash = true
      @db.type_translation = true
      @st = {}
      tune helper;
    end

    def tune (helper)
      # q.v. http://web.utk.edu/~jplyon/sqlite/SQLite_optimization_FAQ.html
      @db.execute_batch(<<'      SQL')
        -- this throws: "SQLite3::SQLException: not authorized" ... why?
        -- SELECT load_extension("#{helper}");
        PRAGMA temp_store=MEMORY;
        PRAGMA journal_mode=MEMORY;
        PRAGMA synchronous=OFF;
        PRAGMA cache_size=200000;
        PRAGMA count_changes=0;
      SQL
    end

    def prepare (sql)
      @st[sql] ||= @db.prepare sql
      return @st[sql]
    end

    def placeholders_for (list)
      (["?"] * list.length).join(",")
    end

    def metaphone (txt)
      leading_digits = /^\d+/.match txt
      if leading_digits
        leading_digits[0]
      else
        Text::Metaphone.metaphone(txt)[0..4]
      end
    end

    def execute (st, *params)
      prepare(st).execute! *params
    end

    def places_by_zip (zip)
      execute "SELECT * FROM place WHERE zip = ?", zip
    end

    def places_by_city (city)
      execute "SELECT * FROM place WHERE city_phone = ?", metaphone(city)
    end

    def candidate_records (number, name, zips)
      in_list = placeholders_for zips
      sql = "SELECT feature.*, range.* FROM feature, range
               WHERE name_phone = ?
               AND feature.zip IN (#{in_list})
               AND range.tlid = feature.tlid
               AND fromhn <= ? AND tohn >= ?"
      params = [metaphone(name)] + zips + [number, number]
      execute sql, *params
    end

    def more_candidate_records (number, name)
      sql = <<'      SQL'
        SELECT feature.*, range.* FROM feature, range
          WHERE name_phone = ?
          AND range.tlid = feature.tlid
          AND fromhn <= ? AND tohn >= ?;
      SQL
      execute sql, metaphone(name), number, number
    end

    def primary_records (edge_ids)
      in_list = placeholders_for edge_ids
      sql = "SELECT feature.*, edge.* FROM feature, edge
               WHERE feature.tlid IN (#{in_list})
               AND edge.tlid = feature.tlid;"
      execute sql, *edge_ids
    end

    def all_ranges (edge_ids)
      in_list = placeholders_for edge_ids
      sql = "SELECT * FROM range WHERE range.tlid IN (#{in_list});"
      execute sql, *edge_ids
    end

    def primary_places (zips)
      in_list = placeholders_for zips
      sql = "SELECT * FROM place WHERE zip IN (#{in_list}) AND paflag = 'P';"
      execute sql, *zips
    end
  end
end
