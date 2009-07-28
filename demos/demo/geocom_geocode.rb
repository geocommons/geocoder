require 'config/bootstraps'

module GeocomGeocode
  class GeocodeServer < Sinatra::Base
    register Sinatra::GeocodeWrap  
    configure do
      Straps.framework.apply_settings!(self)
    end 
  end
end
