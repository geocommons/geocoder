$LOAD_PATH.unshift '../lib'

require 'test/unit'
require 'geocoder/us/database'
require 'fastercsv'

Base = File.dirname(__FILE__)

module Geocoder::US
  Database_File = (
    (ARGV[0] and ARGV[0].any?) ? ARGV[0] : "/mnt/tiger2008/geocoder.db")
end

class TestDatabase < Test::Unit::TestCase
  def get_db
    begin
      Geocoder::US::Database.new(Geocoder::US::Database_File)
    rescue ArgumentError
      assert true # dummy assertion to keep test from failing
      nil
    end
  end
  def test_load
    db = get_db
    return if db.nil?
    assert_kind_of Geocoder::US::Database, db 
  end
  def test_place
    db = get_db
    return if db.nil?
    [
      {:city=>"Chicago", :zip=>"60601", :state=>"IL", :precision=>:city,
       :fips_county=>"17031", :lon=>"-87.68732", :lat=>"41.811929"},
      {:city=>"Philadelphia", :zip=>"19019", :state=>"PA", :precision=>:city,
       :fips_county=>"42101", :lon=>"-75.11787", :lat=>"40.001811"}
    ].each {|record|
      result = db.geocode(record[:city] + ", " + record[:state])
      assert_equal result.length, 1
      record.keys.each {|key| assert_equal result[0][key], record[key] }
      result = db.geocode(record[:zip])
      assert_equal result.length, 1
      record[:precision] = :zip
      record.keys.each {|key| assert_equal result[0][key], record[key] }
    }
  end
  def test_sample
    db = get_db
    return if db.nil?
    FasterCSV.foreach(Base + "/data/db-test.csv", {:headers=>true}) do |row|
      result = db.geocode(row[0])
      result[0][:count] = result.map{|a|[a[:lat], a[:lon]]}.to_set.length
      fields = row.headers - ["comment", "address"]
      fields.each {|f|
        sample = row[f] || ""
        given  = result[0][f.to_sym] || ""
        sample = sample.to_f if given.kind_of? Float or given.kind_of? Fixnum
        assert_equal sample, given, "sample: #{sample.inspect}, given: #{given.inspect}"
      }
    end
  end
end
