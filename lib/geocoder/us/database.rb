require 'rubygems'
require 'sqlite3'
require 'text'

require 'set'
require 'time'

require 'geocoder/us/address'

module Geocoder
end

module Geocoder::US
  # Provides an interface to a Geocoder::US database.
  class Database
    Address_Weight = 1.0
    City_Weight = 1.0

    # Takes the path of an SQLite 3 database prepared for Geocoder::US
    # as the sole mandatory argument. The helper argument points to the
    # Geocoder::US SQLite plugin; the module looks for this in the same
    # directory as database.rb by default. The cache_size argument is
    # measured in kilobytes and is used to set the SQLite cache size; larger
    # values will trade memory for speed in long-running processes.
    def initialize (filename, options)
      defaults = {:debug => :false, :cache_size => 50000, :helper => "sqlite3.so"} 
      options = defaults.merge options
      raise ArgumentError, "can't find database #{filename}" \
        unless File.exists? filename
      @db = SQLite3::Database.new( filename )
      @st = {}
      @memo = {}
      @debug = options[:debug]
      tune options[:helper], options[:cache_size]
    end

  #private

    # Load the SQLite extension and tune the database settings.
    # q.v. http://web.utk.edu/~jplyon/sqlite/SQLite_optimization_FAQ.html
    def tune (helper, cache_size)
      if File.expand_path(helper) != helper
        helper = File.join(File.dirname(__FILE__), helper)
      end
      @db.enable_load_extension(1)
      @db.load_extension(helper)
      @db.enable_load_extension(0)
      @db.cache_size = cache_size
      @db.temp_store = "memory"
      @db.synchronous = "off"
    end

    # Return a cached SQLite statement object, preparing it first if
    # it's not already in the cache.
    def prepare (sql)
      print "SQL : #{sql}\n" if @debug
      @st[sql] ||= @db.prepare sql
      return @st[sql]
    end

    # Generate enough SQL placeholders for a list of objects.
    def placeholders_for (list)
      (["?"] * list.length).join(",")
    end

    # Generate enough SQL placeholders for a list of objects.
    def metaphone_placeholders_for (list)
      (["metaphone(?,5)"] * list.length).join(",")
    end

    # Execute an SQL statement, bind a list of parameters, and
    # return the result as a list of hashes.
    def execute (sql, *params)
      st = prepare(sql) 
      execute_statement st, *params
    end

    # Execute an SQLite statement object, bind the parameters,
    # map the column names to symbols, and return the rows
    # as a list of hashes.
    def execute_statement (st, *params)
      if @debug
        start = Time.now
        print "EXEC: #{params.inspect}\n"
      end
      result = st.execute(*params)
      columns = result.columns.map {|c| c.to_sym}
      rows = []
      result.each {|row| rows << Hash[*(columns.zip(row).flatten)]}
      if @debug
        runtime = format("%.3f", Time.now - start)
        print "ROWS: #{rows.length} (#{runtime}s)\n" if @debug
      end
      rows
    end

    def places_by_zip (city, zip)
      execute("SELECT *, levenshtein(?, city) AS city_score
               FROM place WHERE zip = ?", city, zip)
    end

    # Query the place table for by city, optional state, and zip.
    # The metaphone index on the place table is used to match
    # city names.
    def places_by_city (city, tokens, state)
      if state.nil? or state.empty?
        and_state = ""
        args = [city] + tokens.clone
      else
        and_state = "AND state = ?"
        args = [city] + tokens.clone + [state]
      end
      metaphones = metaphone_placeholders_for tokens
      execute("SELECT *, levenshtein(?, city) AS city_score
                FROM place WHERE city_phone IN (#{metaphones}) #{and_state}", *args)
    end

    # Generate an SQL query and set of parameters against the feature and range
    # tables for a street name and optional building number. The SQL is
    # used by candidate_records and more_candidate_records to filter results
    # by ZIP code.
    def candidate_records_query (street, tokens, number=nil)
      metaphones = (["metaphone(?,5)"] * tokens.length).join(",")
      sql = "
        SELECT feature.*, range.*, levenshtein(?, street) AS street_score
          FROM feature, range
          WHERE street_phone IN (#{metaphones})
          AND range.tlid = feature.tlid
          AND range.zip = feature.zip"
      params = [street] + tokens.clone
      if number and number.any?
        sql += "
          AND ((fromhn < tohn AND ? BETWEEN fromhn AND tohn)
           OR  (fromhn > tohn AND ? BETWEEN tohn AND fromhn))" 
        params += [number, number]
      end
      return [sql, params]
    end

    # Query the feature and range tables for a set of ranges, given a
    # building number, street name, and list of candidate ZIP codes.
    # The metaphone and ZIP code indexes on the feature table are
    # used to match results.
    def candidate_records (number, street, tokens, zips)
      sql, params = candidate_records_query(street, tokens, number)
      in_list = placeholders_for zips
      sql    += " AND feature.zip IN (#{in_list})"
      params += zips
      execute sql, *params
    end

    # Query the feature and range tables for a set of ranges, given a
    # building number, street name, and list of candidate ZIP codes.
    # The ZIP codes are reduced to a set of 3-digit prefixes, broadening
    # the search area.
    def more_candidate_records (number, street, tokens, zips)
      sql, params = candidate_records_query(street, tokens, number)
      if zips.any?
        zip3s = zips.map {|z| z[0..2]+'%'}.to_set.to_a
        like_list = zip3s.map {|z| "feature.zip LIKE ?"}.join(" OR ")
        sql += " AND (#{like_list})"
        params += zip3s
      end
      st = @db.prepare sql
      execute_statement st, *params
    end

    # Query the edge table for a list of edges matching a list of edge IDs.
    def edges (edge_ids)
      in_list = placeholders_for edge_ids
      sql = "SELECT edge.* FROM edge WHERE edge.tlid IN (#{in_list})"
      execute sql, *edge_ids
    end

    # Query the feature table for the primary feature names for each of
    # a list of edge IDs.
    def primary_records (edge_ids)
      in_list = placeholders_for edge_ids
      sql = "SELECT feature.*, edge.*
               FROM feature, edge
               WHERE feature.tlid IN (#{in_list})
               AND paflag = 'P'
               AND edge.tlid = feature.tlid;"
      execute sql, *edge_ids
    end

    # Query the range table for all ranges associated with the given
    # list of edge IDs.
    def all_ranges (edge_ids)
      in_list = placeholders_for edge_ids
      sql = "SELECT * FROM range
              WHERE range.tlid IN (#{in_list})
              ORDER BY fromhn ASC;"
      execute sql, *edge_ids
    end

    # Query the place table for notional "primary" place names for each of a
    # list of ZIP codes. Since the place table shipped with this code is
    # bespoke, and constructed from a variety of public domain sources,
    # the primary name for a ZIP is not always the "right" one.
    def primary_places (zips)
      in_list = placeholders_for zips
      sql = "SELECT * FROM place WHERE zip IN (#{in_list}) ORDER BY priority;"
      execute sql, *zips
    end

    # Given a list of rows, find the unique values for a given key.
    def unique_values (rows, key)
      rows.map {|r| r[key]}.to_set.to_a
    end

    # Convert a list of rows into a hash keyed by the given keys.
    def rows_to_h (rows, *keys)
      hash = {}
      rows.each {|row| (hash[row.values_at(*keys)] ||= []) << row; }
      hash
    end

    # Merge the values in the list of rows given in src into the
    # list of rows in dest, matching rows on the given list of keys.
    # May generate more than one row in dest for each input dest row.
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

    def find_candidates (address)
      places = []
      candidates = []

      # FIXME: include prenum in lookup if available
      if address.zip.any?
        places = places_by_zip address.text, address.zip
        if places.any?
          address.city = unique_values places, :city
          candidates = candidate_records address.number, address.text, address.street_parts, [address.zip]
        end
      end

      if candidates.empty?
        places = places_by_city address.text, address.city_parts, address.state
        # FIXME: what happens if we get to here and no places match?
        address.city = unique_values places, :city
        zips = unique_values places, :zip
        candidates = candidate_records address.number, address.text, address.street_parts, zips
      end

      # FIXME: what happens if we get to here and no places match?
      if candidates.empty?
        # no exact range match?
        candidates = candidate_records nil, address.text, address.street_parts, zips
      end
     
      # -- this takes too long for certain streets...
      if candidates.empty?
        candidates = more_candidate_records address.number, address.text, address.street_parts, zips
      end

      # need to join up places and candidates here
      merge_rows! candidates, places, :zip
      candidates
    end

    # Given a query hash and a list of candidates, assign :number
    # and :precision values to each candidate. If the query building
    # number is inside the candidate range, set the number on the result
    # and set the precision to :range; otherwise, find the closest
    # corner and set precision to :street.
    def assign_number! (hn, candidates)
      hn = 0 unless hn
      for candidate in candidates
        fromhn, tohn = candidate[:fromhn].to_i, candidate[:tohn].to_i
        if (hn >= fromhn and hn <= tohn) or (hn <= fromhn and hn >= tohn)
          candidate[:number] = hn.to_s
          candidate[:precision] = :range
        else
          candidate[:number] = ((hn - fromhn).abs < (hn - tohn).abs ?
                                candidate[:fromhn] : candidate[:tohn])
          candidate[:precision] = :street
        end
      end
    end

    # Score a list of candidates. For each candidate:
    # * For each item in the query:
    # ** if the query item is blank but the candidate is not, score 0.15;
    #    otherwise, if both are blank, score 1.0.
    # ** If both items are set, compute the scaled Levenshtein-Damerau distance
    #    between them, and add that value (between 0.0 and 1.0) to the score.
    # * Add 0.5 to the score for each numbered end of the range that matches
    #   the parity of the query number.
    # * Add 1.0 if the query number is in the candidate range, otherwise
    #   add a fractional value for the notional distance between the
    #   closest candidate corner and the query.
    # * Finally, divide the score by the total number of comparisons.
    #   The result should be between 0.0 and 1.0, with 1.0 indicating a
    #   perfect match.
    def score_candidates! (address, candidates)
      for candidate in candidates
        compare = [:prenum, :state, :zip]
        denominator = compare.length + Address_Weight + City_Weight

        score = (1.0 - candidate[:street_score].to_f) * Address_Weight
        score += (1.0 - candidate[:city_score].to_f) * City_Weight
        compare.each {|key| score += 1 if address.send(key) == candidate[key]}

        if candidate[:intersect_score] 
          score += 1.0 - candidate[:intersect_score]
          denominator += 1
        elsif address.number and address.number.any?
          # FIXME: I get the feeling that this doesn't belong here anymore
          fromhn, tohn, hn = [candidate[:fromhn], 
                              candidate[:tohn], 
                              address.number].map {|s|s.to_i}
          score += 0.5 if fromhn % 2 == hn % 2
          score += 0.5 if tohn % 2 == hn % 2
          if candidate[:precision] == :range
            score += 1
          else
            score += 1.0/(candidate[:number].to_i - hn).abs
          end
          denominator += 2
        end

        candidate[:score] = score.to_f / denominator
      end
    end

    # Find the candidates in a list of candidates that are tied for the
    # top score and prune the remainder from the list.
    def best_candidates! (candidates)
      # lookup.rst (8)
      candidates.sort! {|a,b| b[:score] <=> a[:score]}
      candidates.delete_if {|record| record[:score] < candidates[0][:score]}
    end

    # From a hash of ranges keyed by edge ID, find the ranges that
    # match the edge ID and the street side of a given candidate.
    def ranges_for_record (ranges, record)
      key = record.values_at(:tlid)
      ranges[key].select {|r| r[:side] == record[:side]}
    end

    # Compute the fractional interpolation distance for a query number along an
    # edge, given all of the ranges for the same side of that edge.
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

    # Unpack an array of little-endian 4-byte ints, and convert them into
    # signed floats by dividing by 10^6, inverting the process used by the
    # compress_wkb_line() function in the SQLite helper extension.
    def unpack_geometry (geom)
      points = []
      coords = geom.unpack "V*" # little-endian 4-byte long ints
      # now map them into signed floats
      coords.map! {|i| ( i > (1 << 31) ? i - (1 << 32) : i ) / 1_000_000.0}
      points << [coords.shift, coords.shift] until coords.empty?
      points
    end

    # Calculate the longitude scaling for the average of two latitudes.
    def scale_lon (lat1,lat2)
      # an approximation in place of lookup.rst (10e) and (10g)
      # = scale longitude distances by the cosine of the latitude
      # (or, actually, the mean of two latitudes)
      # -- is this even necessary?
      Math.cos((lat1+lat2) / 2 * Math::PI / 180)
    end

    # Simple Euclidean distances between two 2-D coordinate pairs, scaled
    # along the longitudinal axis by scale_lon.
    def distance (a, b)
      dx = (b[0] - a[0]) * scale_lon(a[1], b[1])
      dy = (b[1] - a[1]) 
      Math.sqrt(dx ** 2 + dy ** 2)
    end

    # Find an interpolated point along a list of linestring vertices
    # proportional to the given fractional distance along the line.
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

    # Find and replace the city, state, and county information
    # in a list of candidates with the primary place information
    # for the ZIP codes in the candidate list.
    def canonicalize_places! (candidates)
      zips_used  = unique_values(candidates, :zip)
      pri_places = rows_to_h primary_places(zips_used), :zip
      candidates.map! {|record|
        current_places = pri_places[[record[:zip]]]
        # FIXME: this should never happen!
        return [] unless current_places
        top_priority = current_places.map{|p| p[:priority]}.min
        current_places.select {|p| p[:priority] == top_priority}.map {|p|
          record.merge({
            :city => p[:city], 
            :state => p[:state], 
            :fips_county => p[:fips_county]
          })
        }
      } 
      candidates.flatten!
    end

    # Clean up a candidate record by formatting the score, replacing nil
    # values with empty strings, and deleting artifacts from database
    # queries.
    def clean_record! (record)
      record[:score] = format("%.3f", record[:score]).to_f \
        unless record[:score].nil?
      record.keys.each {|k| record[k] = "" if record[k].nil? } # clean up nils
      record.delete_if {|k,v| k.is_a? Fixnum or
          [:geometry, :side, :tlid, :street_phone,
           :city_phone, :fromhn, :tohn, :paflag,
           :priority, :fips_class, :fips_place, :status].include? k}
    end

    def best_places (address, places, canonicalize=false)
      return [] unless places.any?
      score_candidates! address, places
      best_candidates! places 
      canonicalize_places! places if canonicalize

      # uniqify places
      by_name = rows_to_h(places, :city, :state)
      by_name.values.each {|v| v.sort! {|a,b| a[:zip] <=> b[:zip]}}
      places = by_name.map {|k,v| v[0]}
   
      places.each {|record| clean_record! record}
      places.each {|record|
        record[:precision] = (record[:zip] == address.zip ? :zip : :city)
      }
      places
    end

    # Given an Address object, return a list of possible geocodes by place
    # name. If canonicalize is true, attempt to return the "primary" postal
    # place name for the given city, state, or ZIP.
    def geocode_place (address, canonicalize=false)
      if address.zip.any?
        places = places_by_zip address.text, address.zip
      else
        places = places_by_city address.text, address.city_parts, address.state
      end
      best_places address, places, canonicalize
    end

    def merge_edges! (candidates, canonicalize=false)
      edge_ids = unique_values candidates, :tlid
      if canonicalize
        records  = primary_records edge_ids
        merge_rows! candidates, records, :tlid, :zip
      else
        records  = edges edge_ids
        merge_rows! candidates, records, :tlid
      end
      edge_ids
    end

    def intersecting_angle (a, b, c, d)
      if a == c
        x, y = a
        leg_c = distance(b,d)
      elsif a == d
        x, y = a
        leg_c = distance(b,c)
      elsif b == c
        x, y = b
        leg_c = distance(a,d)
      elsif b == d
        x, y = b
        leg_c = distance(a,c)
      else
        return nil,nil,nil
      end
      leg_a = distance(a,b)
      leg_b = distance(c,d)
      # Law of Cosines
      if leg_a > 0 and leg_b > 0
        cos_angle = (leg_a ** 2 + leg_b ** 2 - leg_c ** 2)/(2 * leg_a * leg_b)
        [x, y, Math.acos(cos_angle)]
      else
        [x, y, 0.0]
      end
    end

    def find_intersections (candidates)
      points = {}
      intersects = []
      candidates.each {|record|
        [record[:geometry][0], record[:geometry][-1]].each {|point|
          points[point] ||= []
          points[point] << record
        }
      }
      points.values.each {|recordset|
        recordset.each_index {|i|
          record1 = recordset[i]
          a, b = record1[:geometry][0], record1[:geometry][-1]
          (i+1...recordset.length).each {|j|
            record2 = candidates[j]
            next if record1[:tlid] == record2[:tlid] \
                 or record1[:street] == record2[:street]
            c, d = record2[:geometry][0], record2[:geometry][-1]
            x, y, angle = intersecting_angle a, b, c, d
            next unless angle
            record = record1.clone
            record[:street1] = record.delete(:street)
            record[:street2] = record2[:street]
            record[:street_score] = (
              record1[:street_score].to_f+record2[:street_score].to_f)/2
            record[:lon] = x
            record[:lat] = y
            record[:intersect_score] = (Math::PI-2*angle).abs/Math::PI
            intersects << record
          }
        }
      }
      intersects
    end

    def geocode_intersection (address, canonicalize=false)
      candidates = find_candidates address
      merge_edges! candidates, canonicalize
      candidates.each {|record|record[:geometry] = unpack_geometry record[:geometry]}
      candidates = find_intersections candidates
      score_candidates! address, candidates
      best_candidates! candidates 

      by_point = rows_to_h(candidates, :lon, :lat)
      candidates = by_point.values.map {|records| records[0]}

      canonicalize_places! candidates if canonicalize
      candidates.each {|record| clean_record! record}
      candidates
    end

    # Given an Address object, return a list of possible geocodes by address
    # range interpolation. If canonicalize is true, attempt to return the
    # "primary" street and place names, if they are different from the ones
    # given.
    def geocode_address (address, canonicalize=false)
      candidates = find_candidates address

      # FIXME: this is the point we should be looking for intersections.
      assign_number! address.number.to_i, candidates

      score_candidates! address, candidates
      best_candidates! candidates 

      # if no number is assigned in the query, only return one
      # result for each street/zip combo
      if address.number.none?
        by_street = rows_to_h candidates, :street, :zip
        candidates = by_street.values.map {|records| records[0]}
      end

      edge_ids = merge_edges! candidates, canonicalize

      ranges  = rows_to_h all_ranges(edge_ids), :tlid
      candidates.map {|record|
        side_ranges = ranges_for_record ranges, record
        dist = interpolation_distance( address.number.to_i, side_ranges )
        points = unpack_geometry record[:geometry]
        record[:lon], record[:lat] = interpolate points, dist
      }
      
      canonicalize_places! candidates if canonicalize

      candidates.each {|record| clean_record! record}
      candidates
    end

  public

    # Geocode a given address or place name string. The max_penalty and cutoff
    # arguments are passed to the Address parse functions. If canonicalize is
    # true, attempt to return the "primary" street and place names, if they are
    # different from the ones given.
    #
    # Returns possible candidate matches as a list of hashes.
    #
    # * The :lat and :lon values of each hash store the range-interpolated
    #   address coordinates as latitude and longitude in the WGS84 spheroid.
    # * The :precision value may be one of :city, :zip, :street, or :range, in
    #   order of increasing precision.
    # * The :score value will be a float between 0.0 and 1.0 representing
    #   the approximate "goodness" of the candidate match.
    # * The other values in the hash will represent various structured
    #   components of the address and place name.
    def geocode (string, canonicalize=false)
      address = Address.new string
      print "ADDR: #{address.inspect}\n" if @debug
      return [] if address.city.none? and address.zip.none?
      results = []
      start_time = Time.now if @debug
      if address.intersection? and address.street.any?
        results = geocode_intersection address, canonicalize
      end
      if results.empty? and address.street.any?
        results = geocode_address address, canonicalize
      end
      if results.empty?
        results = geocode_place address, canonicalize
      end
      if @debug
        runtime = format("%.3f", Time.now - start_time)
        print "DONE: #{runtime}s\n"
      end
      results
    end
  end
end
