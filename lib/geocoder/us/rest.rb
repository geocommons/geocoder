require 'sinatra'
require 'geocoder/us/database'
require 'json'

@@db = Geocoder::US::Database.new(ARGV[0] || ENV["GEOCODER_DB"])

get '/geocode' do
  if params[:q]
    results = @@db.geocode params[:q]
    features = []
    results.each do |result|
      coords = [result.delete(:lon), result.delete(:lat)]
      features << {
        :type => "Feature",
        :properties => result,
        :geometry => {
          :type => "Point",
          :coordinates => coords
        }
      }
    end
    {
      :type => "FeatureCollection",
      :address => params[:q],
      :features => features
    }.to_json
  else
    status 400
    "parameter 'q' is missing"
  end
end
