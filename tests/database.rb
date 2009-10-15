$LOAD_PATH.unshift '../lib'

require 'test/unit'
require 'geocoder/us/database'
require 'fastercsv'

Base = File.dirname(__FILE__)

module Geocoder::US
  Database_File = (
    (ARGV[0] and !ARGV[0].empty?) ? ARGV[0] : "/Users/katechapman/shineygeocoder.db")
end

class TestDatabase < Test::Unit::TestCase
  def get_db
    Geocoder::US::Database.new(Geocoder::US::Database_File, {:debug => true})

  end
  
  def setup
    @db = get_db
    assert_not_nil @db
  end
  
  def test_load
    return if @db.nil?
    assert_kind_of Geocoder::US::Database, @db 
  end

  def test_zip
    return if @db.nil?
    [ {:city=>"Chicago", :zip=>"60601", :state=>"IL", :precision=>:zip,
       :fips_county=>"17031", :lon=>"-87.68732", :lat=>"41.811929", :score => 0.714},
      {:city=>"Philadelphia", :zip=>"19019", :state=>"PA", :precision=>:zip,
       :fips_county=>"42101", :lon=>"-75.11787", :lat=>"40.001811", :score => 0.714}
    ].each {|record|
      result = @db.geocode(record[:zip])
      assert_equal result.length, 1
      record.keys.each {|key| assert_equal record[key], result[0][key]}
    }
  end

  def test_place
    return if @db.nil?
    [ {:city=>"Chicago", :state=>"IL", :precision=>:city, :fips_county=>"17031", :score => 0.857},
      {:city=>"Philadelphia", :state=>"PA", :precision=>:city, :fips_county=>"42101", :score => 0.857}
    ].each {|record|
      result = @db.geocode(record[:city] + ", " + record[:state])
      assert_equal result.length, 1
      record.keys.each {|key| assert_equal record[key], result[0][key]}
    }
  end
  
  def test_sample
    return if @db.nil?
    FasterCSV.foreach(Base + "/data/db-test.csv", {:headers=>true}) do |row|
      result = @db.geocode(row[0], true)
      result[0][:count] = result.map{|a|[a[:lat], a[:lon]]}.to_set.length
      fields = row.headers - ["comment", "address"]
      fields.each {|f|
        sample = row[f] || ""
        given  = result[0][f.to_sym] || ""
        sample = sample.to_f if given.kind_of? Float or given.kind_of? Fixnum
        assert_equal sample, given, "row: #{row.inspect}\nfield: #{f.inspect} sample: #{sample.inspect}, given: #{given.inspect}"

      }
    end
  end
  
  def test_should_get_street_number_correctly
    result = @db.geocode("460 West St, Amherst MA 01002-2964", true)
    puts "all results=#{result.inspect}"
    assert_equal '460', result[0][:number] 
  end
  
  def test_should_geocode_with_hash
    result = @db.geocode({:street => "2200 Wilson Blvd", :city => "Arlington", :state => "VA", :postal_code => "22201"}, true)
    result2 = @db.geocode("2200 Wilson Blvd, Arlington, VA 22201")
    assert_equal result2,result
  end
  
  def test_should_work_with_partial_hash
    result = @db.geocode({:street => "2200 Wilson Blvd", :postal_code => "22201"})
    assert_equal result[0][:precision],:range
  end
  
  def test_weird_edge_case_explosion
    result = @db.geocode({:street => "1410 Spring Hill Rd", :postal_code => "20221"})
    result1 = @db.geocode(:street => "402 Valley View Ave", :postal_code => "12345")
    assert_equal result[0][:precision],:zip    
  end
end
