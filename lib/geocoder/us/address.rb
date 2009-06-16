require 'geocoder/us/constants'

module Geocoder::US
  # Defines the matching of parsed address tokens.
  Match = {
    :number   => /(\d+\W|[a-z]+)?(\d+)([a-z]?)/io,
    :abbr     => Std_Abbr,
    :street   => /(?:(?:\d+\w*|[a-z'-]+)\s*)+/io,
    :city     => /(?:[a-z'-]+\s*)+/io,
    :state    => Regexp.new(State.match.source + "\s*$"),
    :zip      => /(\d{5})(?:-\d{4})?\s*$/o,
    :at       => /\s(at|@|and|&)\s/io,
  }
 
  # The Address class takes a US street address or place name and
  # constructs a list of possible structured parses of the address
  # string.
  class Address
    attr_accessor :text
    attr_accessor :prenum
    attr_accessor :number
    attr_accessor :state
    attr_accessor :zip
   
    # Takes an address or place name string as its sole argument.
    def initialize (text)
      @text = clean text
      parse
    end

    # Removes any characters that aren't strictly part of an address string.
    def clean (value)
      value.strip \
           .gsub(/[^a-z0-9 ,'&@-]+/io, "") \
           .gsub(/\s+/o, " ")
    end

    # Expands a token into a list of possible strings based on
    # the Geocoder::US::Name_Abbr constant, and expands numerals and
    # number words into their possible equivalents.
    def expand_token (token)
      token_list = [token]
      if /^\d+(?:st|nd|rd|th)?$/o.match token
        num = token.to_i
      elsif Ordinals[token]
        num = Ordinals[token]
      elsif Cardinals[token]
        num = Cardinals[token]
      end
      token_list = [num.to_s, Ordinals[num], Cardinals[num]] if num and num < 100
    end

    def parse
      text = @text.clone
      @zip = text.scan(Match[:zip])[-1]
      if @zip
        text[$&] = ""
        @zip, @plus4 = @zip.map {|s|s.strip}
      end
      text.sub! /\s*,?\s*$/o, ""
      @state = text.scan(Match[:state])[-1]
      if @state
        text[$&] = ""
        @state = State[@state[0].strip]
      end
      text.sub! /\s*,?\s*$/o, ""
      @number = text.scan(Match[:number])[0]
      if @number
        text[$&] = ""
        @prenum, @number, @sufnum = @number
      end
      text.sub! /^\s*,?\s*/o, ""

      @street = text.scan(Match[:street]).map {|s|s.strip}
      add = @street.map {|item| item.gsub(Name_Abbr.match) {|m| Name_Abbr[m]}}
      @street |= add
      add = @street.map {|item| item.gsub(Std_Abbr.match) {|m| Std_Abbr[m]}}
      @street |= add
      # unfortunate artifact due to \b and S matching "south"
      @street.map! {|s| s.gsub(/'S\b/o, "'s")} 
      @street.sort! {|a,b| a.length <=> b.length}

      @city = text.scan(Match[:city])[-1].map {|s|s.strip}
      add = @city.map {|item| item.gsub(Name_Abbr.match) {|m| Name_Abbr[m]}} 
      @city |= add
      @city.reverse!

      self.city= @city[0] if @city.length == 1
    end

    def street
      strings = []
      @street.each {|string|
        tokens = string.split(" ")
        strings |= (0...tokens.length).map {|i|
                   (i...tokens.length).map {|j| tokens[i..j].join(" ")}}.flatten
      }
      strings.sort {|a,b|
        cmp = b.count(" ") <=> a.count(" ")
        cmp = a.length <=> b.length if cmp == 0
        cmp
      }
    end
  
    def city
      strings = []
      @city.map {|string|
        tokens = string.split(" ")
        strings |= (0...tokens.length).to_a.reverse.map {|i|
                   (i...tokens.length).map {|j| tokens[i..j].join(" ")}}.flatten
      }
      strings
    end

    def city= (string)
      @city = [string.clone]
      match = Regexp.new('\s*' + string + '\s*')
      @street = @street.map {|string| string.gsub(match, "")}.select {|s|s.any?}
    end

    def intersection?
      @tagged.any? {|tag| tag.any? {|t| t == :at}}
    end

    def intersection!
      @tagged.map! {|tag| tag - [:number]}
    end
  end
end
