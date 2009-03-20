require 'set'
require 'geocoder/us/constants'

module Geocoder::US
  Fields = [
    :prenum => nil,
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

    def self.build_match_set (hash)
      matches = Set.new()
      [hash.keys, hash.values].flatten.each {|item|
        tokens = item.split
        tokens.each_index {|i|
          matches << tokens[0..i].join(" ")
        }
      }
      matches
    end
    
    def initialize (text)
      @text = text
    end

    def new_parse (base=nil)
        Hash[Fields.map {|f| base.nil? ? [f,""] : [f,base[f]]}]
    end

    def tokens
      @text.split
    end

    
  end
end
