$LOAD_PATH.unshift '../lib'

require 'test/unit'
require 'geocoder/us/database'
require 'fastercsv'

module Geocoder::US
  Database_File = (
    (ARGV[0] and ARGV[0].any?) ? ARGV[0] : "/mnt/tiger2008/geocoder.db")
  Helper = File.join(File.dirname(__FILE__), "..", "lib",
                     "libsqlite3_geocoder.so")
end

class TestDatabase < Test::Unit::TestCase
  def get_db
    begin
      Geocoder::US::Database.new(
              Geocoder::US::Database_File,
              Geocoder::US::Helper)
    rescue ArgumentError
      assert_true true # dummy assertion to keep test from failing
      nil
    end
  end
  def test_load
    db = get_db
    return if db.nil?
    assert_kind_of Geocoder::US::Database, db 
  end
  def test_sample
    db = get_db
    return if db.nil?
    FasterCSV.foreach("data/db-test.csv", {:headers=>true}) do |row|
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
