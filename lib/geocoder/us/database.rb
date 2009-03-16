require 'rubygems'
require 'sqlite3'
require 'set'
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

    def score_candidates! (query, candidates)
      for candidate in candidates
        score = 0
        # lookup.rst (7a)
        query.keys.each {|k| score += 1 if query[k] == candidate[k]}
        p score
        # lookup.rst (7b)
        # TODO: implement me
        # lookup.rst (7c)
        score += 1  if candidate["fromhn"].to_i % 2 == query["number"].to_i % 2
        p score
        # lookup.rst (7d)
        candidate["score"] = score.to_f / query.keys.length
      end
    end

    def best_candidates! (candidates)
      # lookup.rst (8)
      candidates.sort! {|a,b| b["score"] <=> a["score"]}
      candidates.delete_if {|record| record["score"] < candidates[0]["score"]}
    end

    def geocode (query)
      # lookup.rst (1)
      places = []

      # lookup.rst (2)
      places += places_by_zip query["zip"] if query["zip"] 

      # lookup.rst (3)
      places += places_by_city query["city"] if query["city"]

      # lookup.rst (4)
      zips = (places.map {|p| p["zip"]}).to_set

      # lookup.rst (5)
      candidates = candidate_records query["number"], query["name"], zips.to_a

      # TODO: need to join up places and candidates here
      
      # lookup.rst (6)
      unless candidates
        candidates = more_candidate_records query["number"], query["name"] 
      end

      # lookup.rst (7)
      score_candidates! query, candidates

      # lookup.rst (8)
      best_candidates! candidates 

      # lookup.rst (9)
      # edge_ids = (candidates.map {|r| r["tlid"]}).to_set
      # records  = primary_records edge_ids 
      # TODO: need to join up primary records with ranges, candidate scores, places here
    end
  end
end
