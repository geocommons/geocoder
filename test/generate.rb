#!/usr/bin/ruby

require 'test/unit'
require 'geocoder/us/database'
require 'fastercsv'

db = Geocoder::US::Database.new("/mnt/tiger2008/geocoder.db",
                                "/home/sderle/geocoder/lib/libsqlite3_geocoder.so")

if ARGV.length == 1
  result = db.geocode(ARGV[0], 0, 50)
  p result
else
  FasterCSV.open(ARGV[1], "w", {:headers => true, :write_headers => true}) do |output|
    FasterCSV.foreach(ARGV[0], {:headers => true}) do |row|
      result = db.geocode(row[0])
      count  = result.map{|a|[a[:lat], a[:lon]]}.to_set.length
      if !result.empty?
        row.headers[1..13].each_with_index {|f,i|
          if result[0][f.to_sym] != row[i+1]
            print "#{row[0]} !#{f} -> #{result[0][f]} != #{row[i+1]}\n"
          end
        }
        result[0][:count] = count
        result[0][:address] = row[0]
        result[0][:comment] = row[-1]
        columns = row.headers.map{|col|col.to_sym}
        output << result[0].values_at(*columns)
      else
        print "!!! #{row[0]}\n"
      end
    end
  end
end
