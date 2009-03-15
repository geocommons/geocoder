require 'rubygems'
require 'sqlite3'
require 'geo_ruby'
require 'geocoder/us/address'

module Geocoder::US::Database
  class Database
    def initialize (filename)
      @db = SQLite3::Database.new( filename )
      @db.results_as_hash = true
      @st = {}
      tune;
    end

    def tune
      # q.v. http://web.utk.edu/~jplyon/sqlite/SQLite_optimization_FAQ.html
      @db.execute_batch(<<'      SQL')
        PRAGMA temp_store=MEMORY;
        PRAGMA journal_mode=MEMORY;
        PRAGMA synchronous=OFF;
        PRAGMA cache_size=200000;
        PRAGMA count_changes=0;
      SQL
    end

    def prepare (sql)
      if @st.has_key? sql
        @st[sql].reset
      else
        @st[sql] = @db.prepare sql
      end
      return @st[sql]
    end

    def placeholders_for (list)
      (["?"] * list.length).join(",")
    end

    def execute (st, *params)
      @db.execute prepare(st), *params
    end

    def places_by_zip (zip)
      execute "SELECT * FROM place WHERE zip = ?", zip
    end

    def places_by_city (city)
      execute "SELECT * FROM place WHERE city_phone = metaphone(?)", city
    end

    def candidate_records (number, name, zips)
      in_list = placeholders_for zips
      sql = <<'      SQL'
        SELECT feature.*, range.* FROM feature, range
          WHERE name_phone = metaphone(?)
          AND feature.zip IN (#{in_list})
          AND range.tlid = feature.tlid
          AND fromhn >= ? AND tohn <= ?;
      SQL
      params = [name] + zips + [number, number]
      execute sql, *params
    end

    def more_candidate_records (number, name)
      sql = <<'      SQL'
        SELECT feature.*, range.* FROM feature, range
          WHERE name_phone = metaphone(?)
          AND range.tlid = feature.tlid
          AND fromhn >= ? AND tohn <= ?;
      SQL
      execute sql, name, number, number
    end

    def primary_records (edge_ids)
      in_list = placeholders_for edge_ids
      sql = <<'      SQL'
        SELECT feature.*, edge.* FROM feature, edge
          WHERE feature.tlid IN (#{in_list})
          AND edge.tlid = feature.tlid;
      SQL
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
