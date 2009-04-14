require 'rubygems'
require 'sinatra'
require 'geocoder/us/database'

set :port, 8080

get '/' do
  unless params[:address].nil?
    db = Geocoder::US::Database.new("/mnt/tiger2008/geocoder.db")
    @records = db.geocode params[:address]
  end
  case params[:format]
  when /atom/
	builder :index
else
  erb :index
end
end


