require 'sinatra'
require 'geocoder/us/database'
require 'json'

@@db = Geocoder::US::Database.new(ARGV[0] || ENV["GEOCODER_DB"])

set :port, 8081
get '/geocode' do
  if params[:q]
    results = []
    begin
      Timeout.timeout(1.0) do
        results = @@db.geocode params[:q]
      end
    rescue Timeout::Error
      $stderr.print "Timed out on '#{params[:q]}'\n"
    end
    features = []
    results.each do |result|
      coords = [result.delete(:lon), result.delete(:lat)]
      result.keys.each do |key|
        if result[key].is_a? String
          result[key] = result[key].unpack("C*").pack("U*") # utf8
        end
      end
      features << {
        :type => "Feature",
        :properties => result,
        :geometry => {
          :type => "Point",
          :coordinates => coords
        }
      }
    end
    begin
      {
        :type => "FeatureCollection",
        :address => params[:q],
        :features => features
      }.to_json
    rescue JSON::GeneratorError
      { 
        :type => "FeatureCollection",
        :error => "JSON::GeneratorError",
        :features => []
      }.to_json
    end 
  else
    status 400
    "parameter 'q' is missing"
  end
end

get '/health' do
  "All is well."
end
