require 'geocoder/us/constants'

module Geocoder::US
  # Defines the matching of parsed address tokens.
  Match = {
    # FIXME: shouldn't have to anchor :number and :zip at start/end
    :number   => /^(\d+\W|[a-z]+)?(\d+)([a-z]?)\b/io,
    :street   => /(?:\b(?:\d+\w*|[a-z'-]+)\s*)+/io,
    :city     => /(?:\b[a-z'-]+\s*)+/io,
    :state    => Regexp.new(State.regexp.source + "\s*$", Regexp::IGNORECASE),
    :zip      => /(\d{5})(?:-\d{4})?\s*$/o,
    :at       => /\s(at|@|and|&)\s/io,
  }
 
  # The Address class takes a US street address or place name and
  # constructs a list of possible structured parses of the address
  # string.
  class Address
    attr_accessor :text
    attr_accessor :prenum, :number, :sufnum
    attr_accessor :street
    attr_accessor :city
    attr_accessor :state
    attr_accessor :zip, :plus4
   
    # Takes an address or place name string as its sole argument.
    def initialize (text)
      raise ArgumentError, "no text provided" unless text and text.any?
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
    def expand_numbers (string)
      if /\b\d+(?:st|nd|rd|th)?\b/o.match string
        match = $&
        num = $&.to_i
      elsif Ordinals.regexp.match string
        num = Ordinals[$&]
        match = $&
      elsif Cardinals.regexp.match string
        num = Cardinals[$&]
        match = $&
      end
      strings = [string]
      if num and num < 100
        [num.to_s, Ordinals[num], Cardinals[num]].each {|replace|
          strings << string.sub(match, replace)
        }
      end
      strings
    end

    def parse
      text = @text.clone.downcase

      @zip = text.scan(Match[:zip])[-1]
      if @zip
        # FIXME: What if this string appears twice?
        text[$&] = ""
        text.sub! /\s*,?\s*$/o, ""
        @zip, @plus4 = @zip.map {|s|s.strip}
      else
        @zip = @plus4 = ""
      end

      @state = text.scan(Match[:state])[-1]
      if @state
        # FIXME: What if this string appears twice?
        text[$&] = ""
        text.sub! /\s*,?\s*$/o, ""
        @state = State[@state[0].strip]
      else
        @state = ""
      end

      @number = text.scan(Match[:number])[0]
      if @number and not intersection?
        # FIXME: What if this string appears twice?
        text[$&] = ""
        text.sub! /^\s*,?\s*/o, ""
        @prenum, @number, @sufnum = @number.map {|s| s and s.strip}
      else
        @prenum = @number = @sufnum = ""
      end

      # FIXME: special case: detect when @street contains
      # only abbrs, and when it does, stick the number back
      # on the front

      # FIXME: special case: Name_Abbr gets a bit aggressive
      # about replacing St with Saint. exceptional case:
      # Sault Ste. Marie

      @street = text.scan(Match[:street])
      if @street.any?
        @street.map! {|s|s.strip}
        add = @street.map {|item| item.gsub(Name_Abbr.regexp) {|m| Name_Abbr[m]}}
        @street |= add
        add = @street.map {|item| item.gsub(Std_Abbr.regexp) {|m| Std_Abbr[m]}}
        @street |= add
        # unfortunate artifact due to \b and S regexping "south"
        # and a lack of regexp lookbehind in Ruby
        @street.map! {|s| s.gsub(/'S\b/o, "'s")} 
        @street.map! {|item| expand_numbers(item)}
        @street.flatten!
      else
        @street = []
      end
        
      @city = text.scan(Match[:city])
      if @city.any?
        @city = [@city[-1].strip]
        #@city.map! {|s|s.strip}
        add = @city.map {|item| item.gsub(Name_Abbr.regexp) {|m| Name_Abbr[m]}} 
        @city |= add
      else
        @city = []
      end

      self.city= @city if @city.length == 1 and @city != @street
    end

    def street_parts
      strings = []
      # Get all the substrings delimited by whitespace
      @street.each {|string|
        tokens = string.split(" ")
        strings |= (0...tokens.length).map {|i|
                   (i...tokens.length).map {|j| tokens[i..j].join(" ")}}.flatten
      }
      # Don't return strings that consist solely of abbreviations.
      # NOTE: Is this a micro-optimization that has edge cases that will break?
      # Answer: Yes, it breaks on simple things like "Prairie St"
      # Try a simpler case of adding the @number in case everything is an abbr.
      strings += [@number] if strings.all? {|s| Std_Abbr.key? s or Name_Abbr.key? s}

      # Start with the substrings that contain the most tokens, and
      # then proceed in order of "most abbreviated"
      strings.sort {|a,b|
        cmp = b.count(" ") <=> a.count(" ")
        cmp = a.length <=> b.length if cmp == 0
        cmp
      }
    end
  
    def city_parts
      strings = []
      @city.map {|string|
        tokens = string.split(" ")
        strings |= (0...tokens.length).to_a.reverse.map {|i|
                   (i...tokens.length).map {|j| tokens[i..j].join(" ")}}.flatten
      }
      # Don't return strings that consist solely of abbreviations.
      # NOTE: Is this a micro-optimization that has edge cases that will break?
      # Answer: Yes, it breaks on "Prairie"
      #good_strings = strings.reject {|s| Std_Abbr[s] == s}
      #good_strings.any? ? good_strings : strings
      strings
    end

    def city= (strings)
      # NOTE: This will still fail on: 100 Broome St, 33333 (if 33333 is
      # Broome, MT or what)
      match = Regexp.new('\s*(?:' + strings.join("|") + ')\s*$', Regexp::IGNORECASE)
      @street = @street.map {|string| string.gsub(match, '')}.select {|s|s.any?}
    end

    def intersection?
      Match[:at].match @text
    end
  end
end
