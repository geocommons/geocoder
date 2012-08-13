# require 'rubygems'
require 'sqlite3'
# require 'text'
# require 'levenshtein'

require 'set'
require 'pp'
require 'time'
require 'thread'

require 'geocoder/us/address'
require 'geocoder/us/metaphone'

module Geocoder
end

module Geocoder::US
  # Provides an interface to a Geocoder::US database.
  class Database
    Street_Weight = 3.0
    Number_Weight = 2.0
    Parity_Weight = 1.25
    City_Weight = 1.0
    @@mutex = Mutex.new

    # Takes the path of an SQLite 3 database prepared for Geocoder::US
    # as the sole mandatory argument. The helper argument points to the
    # Geocoder::US SQLite plugin; the module looks for this in the same
    # directory as database.rb by default. The cache_size argument is
    # measured in kilobytes and is used to set the SQLite cache size; larger
    # values will trade memory for speed in long-running processes.
    # dbtype option is used when your datasbase encodes it's geometry blogs according to two formats
    # the first. default, is in a series of little-endian 4-byte ints. The second is
    # | 1 byte Type | 4 byte SRID | 4 byte element count| 8 byte double coordinates. Use option value 2 for this
    # second type
    def initialize (filename, options = {})
      defaults = {:debug => false, :cache_size => 50000,
                  :helper => "sqlite3.so", :threadsafe => false,
                  :create => false, :dbtype => 1}
      options = defaults.merge options
      raise ArgumentError, "can't find database #{filename}" \
        unless options[:create] or File.exists? filename
      @db = SQLite3::Database.new( filename )
      @st = {}
      @dbtype = options[:dbtype]
      @debug = options[:debug]
      @threadsafe = options[:threadsafe]
      tune options[:helper], options[:cache_size]
    end

    def synchronize
      if not @threadsafe
        @@mutex.synchronize { yield }
      else
        yield
      end
    end

  #private

    # Load the SQLite extension and tune the database settings.
    # q.v. http://web.utk.edu/~jplyon/sqlite/SQLite_optimization_FAQ.html
    def tune (helper, cache_size)
      if File.expand_path(helper) != helper
        helper = File.join(File.dirname(__FILE__), helper)
      end
      synchronize do
        # @db.create_function("levenshtein", 2) do |func, word1, word2|
        #   test1, test2 = [word1, word2].map {|w|
        #     w.to_s.gsub(/\W/o, "").downcase
        #   }
        #   dist = Levenshtein.distance(test1, test2)
        #   result = dist.to_f / [test1.length, test2.length].max
        #   func.set_result result 
        # end
        # @db.create_function("rb_metaphone", 2) do |func, string, len|
        #  test = string.to_s.gsub(/\W/o, "")
        #  if test =~ /^(\d+)/o
        #    mph = $1
        #  elsif test =~ /^([wy])$/io
        #    mph = $1
        #  else
        #    mph = Text::Metaphone.metaphone test
        #  end
        #  func.result = mph[0...len.to_i]
        # end
        # @db.create_function("nondigit_prefix", 1) do |func, string|
        #   string.to_s =~ /^(.*\D)?(\d+)$/o
        #   func.result = ($1 || "")
        # end
        # @db.create_function("digit_suffix", 1) do |func, string|
        #   string.to_s =~ /^(.*\D)?(\d+)$/o
        #   func.result = ($2 || "")
        # end
        @db.enable_load_extension(1)
        @db.load_extension(helper)
        @db.enable_load_extension(0)
        @db.cache_size = cache_size
        @db.temp_store = "memory"
        @db.synchronous = "off"
      end
    end

    # Return a cached SQLite statement object, preparing it first if
    # it's not already in the cache.
    def prepare (sql)
      $stderr.print "SQL : #{sql}\n" if @debug
      st = nil
      synchronize do
        # don't even bother cache SQL anymore, it seems to be messing things up
        #@st[sql] = @db.prepare sql if not @st[sql] or @st[sql].closed?
        st = @db.prepare sql
      end
      # return @st[sql]
      return st
    end

    def flush_statements
      @st = {}
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
      begin
        execute_statement st, *params
      ensure
        st.close
      end
    end
    
    # Execute an SQLite statement object, bind the parameters,
    # map the column names to symbols, and return the rows
    # as a list of hashes.
    def execute_statement (st, *params)
      if @debug
        start = Time.now
        $stderr.print "EXEC: #{params.inspect}\n" if !params.empty?
      end
      rows = []
      synchronize do
        result = st.execute(*params)
        columns = result.columns.map {|c| c.to_sym}
        result.each {|row|
           rows << Hash[*(columns.zip(row).flatten)]}
        
      end
      if @debug
        runtime = format("%.3f", Time.now - start)
        $stderr.print "ROWS: #{rows.length} (#{runtime}s)\n"
      end
      rows.reverse!
    end
   
    def places_by_zip (city, zip)
      execute("SELECT *, levenshtein(?, city) AS city_score
               FROM place WHERE zip = ? order by priority desc;", city, zip)
    end

    # Query the place table for by city, optional state, and zip.
    # The metaphone index on the place table is used to match
    # city names.
    def places_by_city (city, tokens, state)
      if city.nil?
        city = ""
      end
      if state.nil? or state.empty?
        and_state = ""
        args = [city] + tokens.clone
      else
        and_state = "AND state = ?"
        args = [city] + tokens.clone + [state]
      end
      metaphones = metaphone_placeholders_for tokens
      execute("SELECT *, levenshtein(?, city) AS city_score
                FROM place WHERE city_phone IN (#{metaphones}) #{and_state} order by priority desc;", *args)
    end

    # Generate an SQL query and set of parameters against the feature and range
    # tables for a street name and optional building number. The SQL is
    # used by candidate_records and more_candidate_records to filter results
    # by ZIP code.
    def features_by_street (street, tokens)
      metaphones = (["metaphone(?,5)"] * tokens.length).join(",")
      sql = "
        SELECT feature.*, levenshtein(?, street) AS street_score
          FROM feature
          WHERE street_phone IN (#{metaphones})"
      params = [street] + tokens
      return [sql, params]
    end

    # Query the feature and range tables for a set of ranges, given a
    # building number, street name, and list of candidate ZIP codes.
    # The metaphone and ZIP code indexes on the feature table are
    # used to match results.
    def features_by_street_and_zip (street, tokens, zips)
      sql, params = features_by_street(street, tokens)
      in_list = placeholders_for zips
      sql    += " AND feature.zip IN (#{in_list})"
      params += zips
      execute sql, *params
    end

    # Query the feature and range tables for a set of ranges, given a
    # building number, street name, and list of candidate ZIP codes.
    # The ZIP codes are reduced to a set of 3-digit prefixes, broadening
    # the search area.
    def more_features_by_street_and_zip (street, tokens, zips)
      sql, params = features_by_street(street, tokens)
      if !zips.empty? and !zips[0].nil?
        #puts "zip results 2"
        zip3s = zips.map {|z| z[0..2]+'%'}.to_set.to_a
        like_list = zip3s.map {|z| "feature.zip LIKE ?"}.join(" OR ")
        sql += " AND (#{like_list})"
        params += zip3s
      end
      execute sql, *params
    end

    def ranges_by_feature (fids, number, prenum)
      in_list = placeholders_for fids
      limit = 4 * fids.length
      sql = "
        SELECT feature_edge.fid AS fid, range.*
          FROM feature_edge, range
          WHERE fid IN (#{in_list})
          AND feature_edge.tlid = range.tlid"
      params = fids.clone
      unless prenum.nil?
        sql += " AND prenum = ?"
        params += [prenum]
      end
      sql += " 
          ORDER BY min(abs(fromhn - ?), abs(tohn - ?))
          LIMIT #{limit};"
      params += [number, number]
      execute sql, *params
    end

    # Query the edge table for a list of edges matching a list of edge IDs.
    def edges (edge_ids)
      in_list = placeholders_for edge_ids
      sql = "SELECT edge.* FROM edge WHERE edge.tlid IN (#{in_list})"
      execute sql, *edge_ids
    end

    # Query the range table for all ranges associated with the given
    # list of edge IDs.
    def range_ends (edge_ids)
      in_list = placeholders_for edge_ids
      sql = "SELECT tlid, side,
                    min(fromhn) > min(tohn) AS flipped,
                    min(fromhn) AS from0, max(tohn)   AS to0,
                    min(tohn)   AS from1, max(fromhn) AS to1
              FROM range WHERE tlid IN (#{in_list})
              GROUP BY tlid, side;"
      execute(sql, *edge_ids).map {|r|
	if r[:flipped].to_i == 1
          r[:flipped] = true
          r[:fromhn], r[:tohn] = r[:from1], r[:to1]
        else
          r[:flipped] = false
          r[:fromhn], r[:tohn] = r[:from0], r[:to0]
        end
        [:from0, :to0, :from1, :to1].each {|k| r.delete k}
        r
      }
    end

    def intersections_by_fid (fids)
      temp_db = "temp_" + rand(1<<32).to_s
      temp_table = "intersection_" + rand(1<<32).to_s
      execute "ATTACH DATABASE ':memory:' as #{temp_db};"
      begin
        # flush_statements # the CREATE/DROP TABLE invalidates prepared statements
        in_list = placeholders_for fids
        sql = "
          CREATE TABLE #{temp_db}.#{temp_table} AS
            SELECT fid, substr(geometry,1,8) AS point
                FROM feature_edge, edge 
                WHERE feature_edge.tlid = edge.tlid
                AND fid IN (#{in_list})
            UNION
            SELECT fid, substr(geometry,length(geometry)-7,8) AS point
                FROM feature_edge, edge 
                WHERE feature_edge.tlid = edge.tlid
                AND fid IN (#{in_list});
          CREATE INDEX #{temp_db}.#{temp_table}_pt_idx ON #{temp_table} (point);"
        execute sql, *(fids + fids)
        # the a.fid < b.fid inequality guarantees consistent ordering of street
        # names in the output
        sql = "
          SELECT a.fid AS fid1, b.fid AS fid2, a.point 
              FROM #{temp_table} a, #{temp_table} b,
                   feature f1, feature f2
              WHERE a.point = b.point AND a.fid < b.fid
              AND f1.fid = a.fid AND f2.fid = b.fid
              AND f1.zip = f2.zip
              AND f1.paflag = 'P' AND f2.paflag = 'P';"
        return execute sql
      ensure
        # flush_statements # the CREATE/DROP TABLE invalidates prepared statements
        execute "DETACH DATABASE #{temp_db};"
      end
    end

    # Query the place table for notional "primary" place names for each of a
    # list of ZIP codes. Since the place table shipped with this code is
    # bespoke, and constructed from a variety of public domain sources,
    # the primary name for a ZIP is not always the "right" one.
    def primary_places (zips)
      in_list = placeholders_for zips
      sql = "SELECT * FROM place WHERE zip IN (#{in_list}) order by priority desc;"
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

      city = address.city.sort {|a,b|a.length <=> b.length}[0]
      if(!address.zip.empty? && !address.zip.nil?)
         places = places_by_zip city, address.zip 
      end
      places = places_by_city city, address.city_parts, address.state if places.empty?
      return [] if places.empty?

      # setting city will remove city from street, so save off before
      address.city = unique_values places, :city
      return places if address.street.empty?
      
      zips = unique_values places, :zip
      street = address.street.sort {|a,b|a.length <=> b.length}[0]
      candidates = features_by_street_and_zip street, address.street_parts, zips

      if candidates.empty?
        candidates = more_features_by_street_and_zip street, address.street_parts, zips
      end

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
                                candidate[:fromhn] : candidate[:tohn]).to_s
          candidate[:precision] = :street
        end
      end
    end

    def add_ranges! (address, candidates)
      number = address.number.to_i
      fids   = unique_values candidates, :fid
      ranges = ranges_by_feature fids, number, address.prenum
      ranges = ranges_by_feature fids, number, nil unless !ranges.empty?
      merge_rows! candidates, ranges, :fid
      assign_number! number, candidates
    end

    def merge_edges! (candidates)
      edge_ids = unique_values candidates, :tlid
      records  = edges edge_ids
      merge_rows! candidates, records, :tlid
      candidates.reject! {|record| record[:tlid].nil?}
      edge_ids
    end

    def extend_ranges! (candidates)
      edge_ids    = merge_edges! candidates
      full_ranges = range_ends edge_ids
      merge_rows! candidates, full_ranges, :tlid, :side
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
        candidate[:components] = {}
        compare = [:prenum, :state, :zip]
        denominator = compare.length + Street_Weight + City_Weight

        street_score = (1.0 - candidate[:street_score].to_f) * Street_Weight
        candidate[:components][:street] = street_score
        city_score   = (1.0 - candidate[:city_score].to_f) * City_Weight
        candidate[:components][:city] = city_score
        score = street_score + city_score

        compare.each {|key|
          src  = address.send(key); src = src ? src.downcase : ""
          dest = candidate[key]; dest = dest ? dest.downcase : ""
          item_score = (src == dest) ? 1 : 0
          candidate[:components][key] = item_score
          score += item_score
        }
       
        if address.number and !address.number.empty?
          parity = subscore = 0.0
          fromhn, tohn, assigned, hn = [
              candidate[:fromhn], 
              candidate[:tohn], 
              candidate[:number], 
              address.number].map {|s|s.to_i}
          if candidate[:precision] == :range
            subscore += Number_Weight
          elsif assigned > 0
            # only credit number subscore if assigned
            subscore += Number_Weight/(assigned - hn).abs.to_f
          end
          candidate[:components][:number] = subscore
          if hn > 0 and assigned > 0
            # only credit parity if a number was given *and* assigned
            parity += Parity_Weight/2.0 if fromhn % 2 == hn % 2
            parity += Parity_Weight/2.0 if tohn % 2 == hn % 2
          end
          candidate[:components][:parity] = parity
          score += subscore + parity
          denominator += Number_Weight + Parity_Weight
        end
        candidate[:components][:total] = score.to_f
        candidate[:components][:denominator] = denominator
        candidate[:score] = score.to_f / denominator
      end
    end

    # Find the candidates in a list of candidates that are tied for the
    # top score and prune the remainder from the list.
    def best_candidates! (candidates)
      candidates.sort! {|a,b| b[:score] <=> a[:score]}
      #candidates.reverse_each {|c| print "#{c[:number]} #{c[:state]} #{c[:city]} #{c[:raw_score]} #{c[:number_score]} #{c[:street_score]} #{c[:city_score]}\n" }
      candidates.delete_if {|record| record[:score] < candidates[0][:score]}
    end

    # Compute the fractional interpolation distance for a query number along an
    # edge, given all of the ranges for the same side of that edge.
    def interpolation_distance (candidate)
      fromhn, tohn, number = candidate.values_at(:fromhn, :tohn, :number).map{|x| x.to_i}
      $stderr.print "NUM : #{fromhn} < #{number} < #{tohn} (flipped? #{candidate[:flipped]})\n" if @debug
      # don't need this anymore since range_ends was improved...
      fromhn, tohn = tohn, fromhn if fromhn > tohn
      if fromhn > number
        0.0
      elsif tohn < number
        1.0
      elsif tohn == fromhn
        # this is not supposed to happen, per Census Bureau rules, but apparently it does anyway.
        0.0
      else
        (number - fromhn) / (tohn - fromhn).to_f
      end
    end

    # Unpack an array of little-endian 4-byte ints, and convert them into
    # signed floats by dividing by 10^6, inverting the process used by the
    # compress_wkb_line() function in the SQLite helper extension.
    def unpack_geometry (geom)
      points = []
      if !geom.nil?       
        if @dbtype == 2
          # For special case?
          #| 1 byte Type | 4 byte SRID | 4 byte element count| 8 byte double coordinates *
          info = geom.unpack('CVVD*')
          coords = info.slice(3, info.length)
        else
          #old format
          coords = geom.unpack "V*" # little-endian 4-byte long ints
          ## now map them into signed floats
          coords.map! {|i| ( i > (1 << 31) ? i - (1 << 32) : i ) / 1_000_000.0}
        end
        points << [coords.shift, coords.shift] until coords.empty?
      end
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

    def street_side_offset (b, p1, p2)
      # Find a point (x2, y2) that is at a distance b from a line A=(x0, y0)-(x1, y1)
      # along a tangent B passing through (x1,y1)-(x2,y2).
      # Let a = the length of line A
      a = Math.sqrt((p2[0]-p1[0])**2.0 + (p2[1]-p1[1])**2.0)
      # theta is the angle between the line A and the x axis
      theta = Math.atan2(p2[1]-p1[1], p2[0]-p1[0])
      # Now lines A and B form a right triangle where the third vertex is (x2, y2).
      # Let c = the length of the hypotenuse line C=(x0,y0)-(x2,y2)
      c = Math.sqrt(a**2.0 + b**2.0)
      # Now alpha is the angle between lines A and C.
      alpha = Math.atan2(b, a)
      # Therefore the difference between theta and alpha is the angle between C and
      # the x axis. Since we know the length of C, the lengths of the two lines
      # parallel to the axes that form a right triangle C, and hence the
      # coordinates (x2, y2), fall out.
      return [p1[0] + c * Math.cos(theta - alpha), p1[1] + c * Math.sin(theta - alpha)]
    end

    # Find an interpolated point along a list of linestring vertices
    # proportional to the given fractional distance along the line.
    # Offset is in degrees and defaults to ~8 meters.
    def interpolate (points, fraction, side, offset=0.000075)
      $stderr.print "POINTS: #{points.inspect}" if @debug
      return points[0] if fraction == 0.0 
      return points[-1] if fraction == 1.0 
      total = 0.0
      (1...points.length).each {|n| total += distance(points[n-1], points[n])}
      target = total * fraction
      for n in 1...points.length
        next if points[n-1] == points[n] # because otherwise step==0 and dx/dy==NaN
        step = distance(points[n-1], points[n])
        if step < target
          target -= step
        else
          scale = scale_lon(points[n][1], points[n-1][1])
          dx = (points[n][0] - points[n-1][0]) * (target/step) * scale
          dy = (points[n][1] - points[n-1][1]) * (target/step)
          found = [points[n-1][0]+dx, points[n-1][1]+dy]
          return street_side_offset(offset*side, points[n-1], found)
        end
      end
      # in a pathological case, points[n-1] == points[n] for n==-1
      # so *sigh* just forget interpolating and return points[-1]
      return points[-1]
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
      record.delete :components unless @debug
      record.delete_if {|k,v| k.is_a? Fixnum or
          [:geometry, :side, :tlid, :fid, :fid1, :fid2, :street_phone,
           :city_phone, :fromhn, :tohn, :paflag, :flipped, :street_score,
           :city_score, :priority, :fips_class, :fips_place, :status].include? k}
    end

    def best_places (address, places, canonicalize=false)
      return [] unless !places.empty?
      score_candidates! address, places
      best_candidates! places 
      canonicalize_places! places if canonicalize

      # uniqify places
      by_name = rows_to_h(places, :city, :state)
      if !by_name.nil?
        begin
          by_name.values.each {|v| 
             v.sort! {|a,b|
               a[:zip] <=> b[:zip]
             }}
            rescue

            end
      places = by_name.map {|k,v| v[0]}
   
      places.each {|record| clean_record! record}
      places.each {|record|
        record[:precision] = (record[:zip] == address.zip ? :zip : :city)
      }
      end
      places
    end

    # Given an Address object, return a list of possible geocodes by place
    # name. If canonicalize is true, attempt to return the "primary" postal
    # place name for the given city, state, or ZIP.
    def geocode_place (address, canonicalize=false)
      places = []
      places = places_by_zip address.text, address.zip if !address.zip.empty? or !address.zip.nil?
      places = places_by_city address.text, address.city_parts, address.state if places.empty?
      best_places address, places, canonicalize
    end

    def geocode_intersection (address, canonical_place=false)
      candidates = find_candidates address
      return [] if candidates.empty?
      return best_places(address, candidates, canonical_place) if candidates[0][:street].nil?

      features = rows_to_h candidates, :fid
      intersects = intersections_by_fid features.keys.flatten
      intersects.map! {|record|
        feat1, feat2 = record.values_at(:fid1, :fid2).map {|k| features[[k]][0]}
        record.merge! feat1
        record[:street1] = record.delete(:street)
        record[:street2] = feat2[:street]
        record[:lon], record[:lat] = unpack_geometry(record.delete(:point))[0]
        record[:precision] = :intersection
        record[:street_score] = (feat1[:street_score].to_f + feat2[:street_score].to_f)/2
        record
      }
      #pp(intersects)
      
      score_candidates! address, intersects
      best_candidates! intersects 

      by_point = rows_to_h(intersects, :lon, :lat)
      candidates = by_point.values.map {|records| records[0]}

      canonicalize_places! candidates if canonical_place
      candidates.each {|record| clean_record! record}
      candidates
    end

    # Given an Address object, return a list of possible geocodes by address
    # range interpolation. If canonicalize is true, attempt to return the
    # "primary" street and place names, if they are different from the ones
    # given.
    def geocode_address (address, canonical_place=false)
      candidates = find_candidates address
      return [] if candidates.empty?
      return best_places(address, candidates, canonical_place) if candidates[0][:street].nil?

      score_candidates! address, candidates
      best_candidates! candidates 
    
      #candidates.sort {|a,b| b[:score] <=> a[:score]}.each {|candidate|
      add_ranges! address, candidates
      score_candidates! address, candidates
      #pp candidates.sort {|a,b| b[:score] <=> a[:score]}
      best_candidates! candidates 

      # sometimes multiple fids match the same tlid
      by_tlid = rows_to_h candidates, :tlid
      candidates = by_tlid.values.map {|records| records[0]}

      # if no number is assigned in the query, only return one
      # result for each street/zip combo
      if !address.number.empty?
        extend_ranges! candidates
      else
        by_street = rows_to_h candidates, :street, :zip
        candidates = by_street.values.map {|records| records[0]}
        merge_edges! candidates
      end
      candidates.map {|record|
        dist = interpolation_distance record
        points = unpack_geometry record[:geometry]
        side = (record[:side] == "R" ? 1 : -1)
        if record[:flipped]
          side *= -1
          points.reverse!
        end
        $stderr.print "DIST: #{dist} FLIPPED: #{record[:flipped]} SIDE: #{side}\n" if @debug
        found = interpolate points, dist, side
        record[:lon], record[:lat] = found.map {|x| format("%.6f", x).to_f}
      }
      
      canonicalize_places! candidates if canonical_place

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
    def geocode (info_to_geocode, canonical_place=false)
      address = Address.new info_to_geocode
      $stderr.print "ADDR: #{address.inspect}\n" if @debug
      return [] if address.city.empty? and address.zip.empty?
      results = []
      start_time = Time.now if @debug
      if address.po_box? and !address.zip.empty?
        results = geocode_place address, canonical_place
      end
      if address.intersection? and !address.street.empty? and address.number.empty?
        results = geocode_intersection address, canonical_place
      end
      if results.empty? and !address.street.empty?
        results = geocode_address address, canonical_place
      end
      if results.empty?
        results = geocode_place address, canonical_place
      end
      if @debug
        runtime = format("%.3f", Time.now - start_time)
        $stderr.print "DONE: #{runtime}s\n"
      end
      results
    end
  end
end
