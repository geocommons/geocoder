require 'rubygems'
require 'sinatra'
require 'geocoder/us/database'
require 'json'

set :port, 8080
@@db = Geocoder::US::Database.new("/home/sderle/geocoder/california.db")
get '/geocode.json' do
  if params[:q]
    (@@db.geocode params[:q]).to_json
  else
    status 400
    "parameter 'q' is missing"
  end
end
get '/' do
  unless params[:q].nil?
    @records = @@db.geocode params[:q]
  end
  erb :index
end
