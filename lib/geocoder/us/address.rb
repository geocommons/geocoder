require 'geocoder/us/constants'

module Geocoder::US
  Fields = [
    :prenum,
    :number,
    :sufnum,
    :fraction,
    :predir,
    :prequal,
    :pretyp,
    :street,
    :suftyp,
    :sufqual,
    :sufdir,
    :unittyp,
    :unit,
    :city,
    :state,
    :zip,
    :plus4
  ]
  class Address
    attr_accessor :text
    
    def initialize (text)
      @text = text
    end
  end
end
