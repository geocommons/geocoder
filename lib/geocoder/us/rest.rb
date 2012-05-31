require 'rubygems'
require 'sinatra'
require 'geocoder/us/database'
require 'json'

@@db = Geocoder::US::Database.new(ENV["GEOCODER_DB"] || ARGV[0])

set :port, 8081
get '/geocode.?:format?' do
  if params[:q]
    results = @@db.geocode params[:q].gsub(/\s+(and|at)\s+/i,' ')
    @features = []
    results.each do |result|
      coords = [result.delete(:lon), result.delete(:lat)]
      result.keys.each do |key|
        if result[key].is_a? String
          result[key] = result[key].unpack("C*").pack("U*") # utf8
        end
      end
      @features << {
        :type => "Feature",
        :properties => result,
        :geometry => {
          :type => "Point",
          :coordinates => coords
        }
      }
    end
    case params[:format]
    when /json/
      begin
        {
          :type => "FeatureCollection",
          :address => params[:q],
          :features => @features
        }.to_json
      rescue JSON::GeneratorError
        {
          :type => "FeatureCollection",
          :error => "JSON::GeneratorError",
          :features => []
        }.to_json
      end
    else
      haml :index 
    end
  else
    status 400
    "parameter 'q' is missing"
  end
end

get '/health' do
  "All is well."
end

def radius_for_precision(precision)
  case precision
  when /range/
    50
  else
    200
  end
end

__END__

@@ layout
%html
  %head 
    %link(rel="stylesheet" href="http://leaflet.cloudmade.com/dist/leaflet.css")  
    %script(src="http://leaflet.cloudmade.com/dist/leaflet.js")
    
  %body
    = yield

@@ index
%div#map(style="height:400px")
%div
  %h2 Features
  %table{:border => "1", :cellspacing => "0", :cellpadding => "4"}
    %tr
      - @features.first[:properties].each do |key,property|
        %th= key
    - @features.each do |feature|
      %tr
        - feature[:properties].each do |key,property|
          %td= property
    
%script
  var features = []
  - @features.each do |feature|
    = "features.push(#{feature.to_json})"
  
:javascript
  var map = new L.Map('map');
  var cloudmadeUrl = 'http://acetate.geoiq.com/tiles/acetate/{z}/{x}/{y}.png',
      cloudmadeAttrib = 'Map data &copy; 2011 OpenStreetMap contributors, Style &copy; 2011 GeoIQ',
      cloudmade = new L.TileLayer(cloudmadeUrl, {maxZoom: 18, attribution: cloudmadeAttrib});
  var center = new L.LatLng(#{@features.first[:geometry][:coordinates][1]}, #{@features.first[:geometry][:coordinates][0]});
  map.setView(center, 13).addLayer(cloudmade);
  circleOptions = {
      color: 'red', 
      fillColor: '#f03', 
      fillOpacity: 0.5
  };
  var circleLocation, circle;
  for(var i=0; i<features.length;i++) {
    circleOptions.fillOpacity = features[i].properties.score;
    circleLocation = new L.LatLng(features[i].geometry.coordinates[1],features[i].geometry.coordinates[0]),
    circle = new L.Circle(circleLocation, 200, circleOptions);
    map.addLayer(circle);
  }
