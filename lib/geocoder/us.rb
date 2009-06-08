require "geocoder/us/database"
require "geocoder/us/address"

# Imports the Geocoder::US::Database and Geocoder::US::Address
# modules.
#
# General usage is as follows:
#
#  >> require 'geocoder/us'
#  >> db = Geocoder::US::Database.new("/opt/tiger/geocoder.db")
#  >> p db.geocode("1600 Pennsylvania Av, Washington DC")
#
#  [{:pretyp=>"", :street=>"Pennsylvania", :sufdir=>"NW", :zip=>"20502",
#    :lon=>-77.037528, :number=>"1600", :fips_county=>"11001", :predir=>"",
#    :precision=>:range, :city=>"Washington", :lat=>38.898746, :suftyp=>"Ave",
#    :state=>"DC", :prequal=>"", :sufqual=>"", :score=>0.906, :prenum=>""}]
#
# See Geocoder::US::Database and README.txt for more details.
module Geocoder::US
  VERSION = "2.0.0"
end
