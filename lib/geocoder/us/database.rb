require 'rubygems'
require 'sqlite3'
require 'set'
require 'text'

require 'geocoder/us/address'

module Text::Metaphone
  # this is here because we need to modify the metaphone algo
  # to handle numbers and other special cases according to 
  # own rules... and we don't want to preserve whitespace in 
  # input strings...
  module Rules
    # 'O', not '0' -- for compat with sqlite module
    GEOCODER = BUGGY.dup
    GEOCODER[8] = [ /th/, 'O' ] 
  end

  def metaphone(w, options={})
    # SDE -- Normalise case and remove non-alphanumerics
    s = w.downcase.gsub(/[^a-z0-9]/o, '')
    # SDE -- return just leading numbers to deal with cardinal suffixes
    leading_digits = /^\d+/o.match s
    if leading_digits
      return leading_digits[0]
    end
    # do the actual metaphone transform
    Rules::GEOCODER.each { |rx, rep| s.gsub!(rx, rep) }
    # SDE -- return W or Y if a word starts with that and
    # metaphones to nothing
    if s.empty?
      leading_semivowel = /^\W*([wy])/io.match w
      return leading_semivowel[0].upcase if leading_semivowel
    end
    return s.upcase
  end
end

module Geocoder
end

module Geocoder::US
  class Database
    def initialize (filename, helper="libsqlite3_geocoder.so")
      @db = SQLite3::Database.new( filename )
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

    def metaphone (txt, max_phones=5)
      Text::Metaphone.metaphone(txt)[0...max_phones]
    end

    def execute (sql, *params)
      p sql, params
      st = prepare(sql) 
      result = st.execute(*params)
      columns = result.columns.map {|c| c.to_sym}
      rows = []
      result.each {|row| rows << Hash[*(columns.zip(row).flatten)]}
      rows
    end

    def places_by_zip (zip)
      execute "SELECT * FROM place WHERE zip = ?", zip
    end

    def places_by_city (city)
      execute "SELECT * FROM place WHERE city_phone = ?", metaphone(city,5)
    end

    def places_by_city_or_zip (city, zip)
      execute("SELECT * FROM place WHERE zip = ? or city_phone = ?",
                  zip, metaphone(city,5))
    end

    def candidate_records (number, street, zips)
      in_list = placeholders_for zips
      sql = "SELECT feature.*, range.* FROM feature, range
               WHERE street_phone = ?
               AND feature.zip IN (#{in_list})
               AND range.tlid = feature.tlid
               AND range.zip = feature.zip
               AND ((fromhn < tohn AND ? BETWEEN fromhn AND tohn)
                OR  (fromhn > tohn AND ? BETWEEN tohn AND fromhn))"
      params = [metaphone(street,5)] + zips + [number, number]
      execute sql, *params
    end

    def more_candidate_records (number, street)
      sql = <<'      SQL'
        SELECT feature.*, range.* FROM feature, range
          WHERE street_phone = ?
          AND range.tlid = feature.tlid
          AND range.zip = feature.zip
          AND ((fromhn < tohn AND ? BETWEEN fromhn AND tohn)
           OR  (fromhn > tohn AND ? BETWEEN tohn AND fromhn))"
      SQL
      execute sql, metaphone(street,5), number, number
    end

    def edges (edge_ids)
      in_list = placeholders_for edge_ids
      sql = "SELECT DISTINCT edge.* FROM edge WHERE edge.tlid IN (#{in_list});"
      execute sql, *edge_ids
    end

    def primary_records (edge_ids)
      in_list = placeholders_for edge_ids
      # TODO: the DISTINCT is needed because some TLIDs get duplicated
      # in the edge table... the right way to fix this is to remove
      # them after import; sigh
      sql = "SELECT DISTINCT feature.*, edge.*
               FROM feature, edge
               WHERE feature.tlid IN (#{in_list})
               AND paflag = 'P'
               AND edge.tlid = feature.tlid;"
      execute sql, *edge_ids
    end

    def all_ranges (edge_ids)
      in_list = placeholders_for edge_ids
      sql = "SELECT * FROM range
              WHERE range.tlid IN (#{in_list})
              ORDER BY fromhn ASC;"
      execute sql, *edge_ids
    end

    def primary_places (zips)
      in_list = placeholders_for zips
      sql = "SELECT * FROM place WHERE zip IN (#{in_list}) ORDER BY priority;"
      execute sql, *zips
    end

    def unique_values (rows, key)
      rows.map {|r| r[key]}.to_set.to_a
    end

    def rows_to_h (rows, *keys)
      hash = {}
      rows.each {|row| (hash[row.values_at(*keys)] ||= []) << row; }
      hash
    end

    def merge_rows! (dest, src, *keys)
      src = rows_to_h src, *keys
      dest.map! {|row|
        vals = row.values_at(*keys)
        if src.key? vals
          src[vals].map {|row2| row.merge row2}
        else
          [row]
        end
      }
      dest.flatten!
    end

    def score_candidates! (query, candidates)
      for candidate in candidates
        score = 0
        compare = query.keys.select {|k|
                    not (query[k].nil? or query[k].empty?)}
        compare.each {|k| 
          next if candidate[k].nil?
          # lowercase and eliminate non-word chars before comparison
          a, b = [query,candidate].map{|x| x[k].downcase.gsub(/\W/o, "")}
          if a == b
            # lookup.rst (7a)
            score += 1 
          else
            # lookup.rst (7b)
            distance = Text::Levenshtein.distance(a,b)
            score += 1 - distance.to_f / [a.length,b.length].max
          end
        }

        # lookup.rst (7c)
        # N.B. query includes "number" which will never match so
        # we test separately for parity
        score += 1  if candidate[:fromhn].to_i % 2 == query[:number].to_i % 2

        # lookup.rst (7d)
        candidate[:score] = format("%.3f",score.to_f / compare.length).to_f
      end
    end

    def best_candidates! (candidates)
      # lookup.rst (8)
      candidates.sort! {|a,b| b[:score] <=> a[:score]}
      candidates.delete_if {|record| record[:score] < candidates[0][:score]}
    end

    def ranges_for_record (ranges, record)
      key = record.values_at(:tlid)
      ranges[key].select {|r| r[:side] == record[:side]}
    end

    def interpolation_distance (number, ranges)
      interval = total = 0
      for range in ranges
        fromhn, tohn = range[:fromhn].to_i, range[:tohn].to_i
        fromhn, tohn = tohn, fromhn if fromhn > tohn
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
      points << [coords.shift, coords.shift] until coords.empty?
      points
    end

    def scale_lon (lat1,lat2)
      # an approximation in place of lookup.rst (10e) and (10g)
      # = scale longitude distances by the cosine of the latitude
      # (or, actually, the mean of two latitudes)
      # -- is this even necessary?
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

    def canonicalize_places! (candidates)
      zips_used  = unique_values(candidates, :zip)
      pri_places = rows_to_h primary_places(zips_used), :zip
      candidates.map! {|record|
        current_places = pri_places[[record[:zip]]]
        top_priority = current_places.map{|p| p[:priority]}.min
        current_places.select {|p| p[:priority] == top_priority}.map {|p|
          record.merge({
            :city => p[:city], 
            :state => p[:state], 
            :fips_count => p[:fips_county]
          })
        }
      } 
      candidates.flatten!
    end

    def clean_row! (row)
      row.delete_if {|k,v| k.is_a? Fixnum or
          [:geometry, :side, :tlid, :street_phone,
           :city_phone, :fromhn, :tohn, :paflag,
           :priority, :fips_class, :fips_place, :status].include? k}
    end

    def geocode_address (query, canonicalize=true)
      # lookup.rst (1)
      places = []

      # lookup.rst (2) and (3) together -- index does fine
      places = places_by_city_or_zip query[:city], query[:zip]

      # lookup.rst (4)
      zips = unique_values places, :zip

      # lookup.rst (5)
      candidates = candidate_records query[:number], query[:street], zips
     
      # lookup.rst (6)
      # -- this takes too long for certain streets...
      # if candidates.empty?
      #  candidates = more_candidate_records query[:number], query[:street] 
      # end
      return [] if candidates.empty?

      # need to join up places and candidates here, for scoring
      merge_rows! candidates, places, :zip
  
      # lookup.rst (7)
      score_candidates! query, candidates

      # lookup.rst (8)
      best_candidates! candidates 

      # lookup.rst (9)
      edge_ids = unique_values candidates, :tlid
      if canonicalize
        records  = primary_records edge_ids
      else
        records  = edges edge_ids
      end        

      # lookup.rst (10a) 
      merge_rows! candidates, records, :tlid, :zip

      # lookup.rst (10b)
      ranges  = rows_to_h all_ranges(edge_ids), :tlid

      candidates.map {|record|
        # lookup.rst (10c) & (10d)
        side_ranges = ranges_for_record ranges, record
        dist = interpolation_distance( query[:number].to_i, side_ranges )
        # TODO: implement lookup.rst (10e) & (10g) (projection)
        # lookup.rst (10f) & (10h)
        points = unpack_geometry record[:geometry]
        record[:lon], record[:lat] = interpolate points, dist
        record[:number] = query[:number]
      }
      
      # lookup.rst (11)
      canonicalize_places! candidates if canonicalize
   
      # lookup.rst (12)
      candidates.each {|record| clean_row! record}
      candidates
    end

    def geocode (string, max_penalty=0, cutoff=25, canonicalize=true)
      addr = Address.new string
      for query in addr.parse(max_penalty, cutoff)
        next unless query[:street].any? and (query[:zip].any? \
                                          or query[:city].any?)
        results = geocode_address query, canonicalize
        return results if results.any?
      end
      return []
    end
  end
end
