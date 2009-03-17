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
      # TODO: deal with non-leading digits
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

    def unique_values (rows, key)
      rows.map {|r| r[key]}.to_set.to_a
    end

    def rows_to_h (rows, key)
      hash = {}
      rows.each {|row| (hash[row[key]] ||= []) << row; }
      hash
    end

    def merge_rows! (dest, src, key)
      src = rows_to_h src, key
      dest.map! {|row|
        if src.key? row[key] 
          src[row[key]].map {|row2| row.merge row2}
        else
          [row]
        end
      }
      dest.flatten!
    end

    def score_candidates! (query, candidates)
      for candidate in candidates
        score = 0
        # lookup.rst (7a)
        query.keys.each {|k| score += 1 if query[k] == candidate[k]}
        # lookup.rst (7b)
        # TODO: implement me
        # lookup.rst (7c)
        score += 1  if candidate["fromhn"].to_i % 2 == query["number"].to_i % 2
        # lookup.rst (7d)
        candidate["score"] = score.to_f / query.keys.length
      end
    end

    def best_candidates! (candidates)
      # lookup.rst (8)
      candidates.sort! {|a,b| b["score"] <=> a["score"]}
      candidates.delete_if {|record| record["score"] < candidates[0]["score"]}
    end

    def ranges_for_record (ranges, record)
      ranges[record["tlid"]].select {|r| r["side"] == record["side"]} \
                            .sort {|a,b| a["fromhn"] <=> b["fromhn"]}
    end

    def interpolation_distance (number, ranges)
      interval = total = 0
      for range in ranges
        fromhn, tohn = range["fromhn"].to_i, range["tohn"].to_i
        total += tohn - fromhn
        if fromhn > number
          interval += tohn - fromhn
        elsif fromhn <= number and tohn >= number
          interval += number - fromhn
        end
      end
      return interval.to_f / total.to_f
    end

    def unpack_geometry (geom)
      points = []
      coords = geom.unpack "V*" # little-endian 4-byte long ints
      # now map them into signed floats
      coords.map! {|i| ( i > (1 << 31) ? i - (1 << 32) : i ) / 1_000_000.0}
      coords.each_slice(2) {|x,y| points << [x,y]}
      points
    end

    def scale_lon (lat1,lat2)
      # an approximation in place of lookup.rst (10e) and (10g)
      # = scale longitude distances by the cosine of the latitude
      # (or, actually, the mean of two latitudes)
      # is this even necessary?
      Math.cos((lat1+lat2) / 2 * Math::PI / 180)
    end

    def distance (a, b)
      dx = (b[0] - a[0]) * scale_lon(a[1], b[1])
      dy = (b[1] - a[1]) 
      Math.sqrt(dx ** 2 + dy ** 2)
    end

    def interpolate (points, fraction)
      return points[0] if fraction == 0.0 
      return points[-1] if fraction == 1.0 
      total = 0.0
      (1...points.length).each {|n| total += distance(points[n-1], points[n])}
      target = total * fraction
      for n in 1...points.length
        step = distance(points[n-1], points[n])
        if step < target
          target -= step
        else
          scale = scale_lon(points[n][1], points[n-1][1])
          dx = (points[n][0] - points[n-1][0]) * (target/step) * scale
          dy = (points[n][1] - points[n-1][1]) * (target/step)
          found = [points[n-1][0]+dx, points[n-1][1]+dy]
          return found.map {|x| format("%.6f", x).to_f}
        end
      end
      raise "Can't happen!"
    end

    def clean_row! (row)
      row.delete_if {|k,v| k.is_a? Fixnum or
          %w{geometry side tlid name_phone 
             city_phone fromhn tohn paflag}.include? k}
    end

    def geocode (query)
      # lookup.rst (1)
      places = []

      # lookup.rst (2)
      places += places_by_zip query["zip"] if query["zip"] 

      # lookup.rst (3)
      places += places_by_city query["city"] if query["city"]

      # lookup.rst (4)
      zips = unique_values places, "zip"

      # lookup.rst (5)
      candidates = candidate_records query["number"], query["name"], zips
     
      # lookup.rst (6)
      if candidates.empty?
        candidates = more_candidate_records query["number"], query["name"] 
      end

      return [] if candidates.empty?

      # TODO: need to join up places and candidates here
      merge_rows! candidates, places, "zip"
  
      # lookup.rst (7)
      score_candidates! query, candidates

      # lookup.rst (8)
      best_candidates! candidates 

      # lookup.rst (9)
      edge_ids = unique_values candidates, "tlid"
      records  = primary_records edge_ids

      # lookup.rst (10a) 
      merge_rows! candidates, records, "tlid"

      # lookup.rst (10b)
      ranges  = rows_to_h all_ranges(edge_ids), "tlid"

      candidates.each {|record|
        # lookup.rst (10c) & (10d)
        side_ranges = ranges_for_record ranges, record
        dist = interpolation_distance( query["number"].to_i, side_ranges )
        # TODO: implement lookup.rst (10e) & (10g) (projection)
        # lookup.rst (10f) & (10h)
        points = unpack_geometry record["geometry"]
        record["lon"], record["lat"] = interpolate points, dist
        record["number"] = query["number"]
      }

      # lookup.rst (11)
      zips = unique_values candidates, "zip"
      merge_rows! candidates, primary_places(zips), "zip"

      # lookup.rst (12)
      candidates.each {|record| clean_row! record}
      candidates
    end
  end
end
