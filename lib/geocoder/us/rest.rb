require 'sinatra'
require 'geocoder/us/database'
require 'json'
require 'timeout'

get '/geocode' do
  if params[:q]
    db = Geocoder::US::Database.new(ARGV[0] || ENV["GEOCODER_DB"])
    results = []
    begin
      Timeout.timeout(1.0) do
        results = db.geocode params[:q]
      end
    rescue Timeout::Error
      $stderr.print "Timed out on '#{params[:q]}'\n"
    end
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
