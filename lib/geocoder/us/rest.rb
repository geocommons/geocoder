require 'sinatra'
require 'geocoder/us/database'
require 'json'

@@db = Geocoder::US::Database.new(ARGV[0] || ENV["GEOCODER_DB"])
get '/geocode' do
  if params[:q]
    {
      :results => @@db.geocode(params[:q]),
      :address => params[:q]
    }.to_json
  else
    status 400
    "parameter 'q' is missing"
  end
end
