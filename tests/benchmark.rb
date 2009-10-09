#!/usr/bin/ruby

require 'test/unit'
require 'geocoder/us/database'
require 'benchmark'
include Benchmark          # we need the CAPTION and FMTSTR constants

db = Geocoder::US::Database.new("/mnt/tiger2008/geocoder.db")

n = 50
s = "1005 Gravenstein Hwy N, Sebastopol CA 95472"
a = Geocoder::US::Address.new(s)

print db.geocode(s)

Benchmark.bmbm do |x|
  x.report("parse max_penalty=0") { n.times{a.parse(0)} }
  x.report("parse max_penalty=1") { n.times{a.parse(1)} }
  x.report("geocode") { n.times{db.geocode(s)} }
end
