require 'geocoder/us/address'
require 'pp'

pp(Geocoder::US::Address.new(ARGV[0]))
