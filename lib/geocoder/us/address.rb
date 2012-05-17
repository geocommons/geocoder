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
    :po_box => /\b[P|p]*(OST|ost)*\.*\s*[O|o|0]*(ffice|FFICE)*\.*\s*[B|b][O|o|0][X|x]\b/
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
    def initialize(text)
      raise ArgumentError, "no text provided" unless text and !text.empty?
      if text.class == Hash
        @text = ""
        assign_text_to_address text
      else
        @text = clean text
        parse
      end
    end

    # Removes any characters that aren't strictly part of an address string.
    def clean(value)
      value.strip \
           .gsub(/[^a-z0-9 ,'&@\/-]+/io, "") \
           .gsub(/\s+/o, " ")
    end
   
   
    def assign_text_to_address(text)
      if text[:address]
        @text = clean text[:address]
        parse
      else
        @street = []
        @prenum = text[:prenum] 
        @sufnum = text[:sufnum] 
        if !text[:street].nil?
          @street = text[:street].scan(Match[:street])
        end
        @number = ""
        if !@street.nil?
          if text[:number].nil?
             @street.map! { |single_street|
               single_street.downcase!
               @number = single_street.scan(Match[:number])[0].to_s
               single_street.sub! @number, ""
               single_street.sub! /^\s*,?\s*/o, ""
              }
         else
            @number = text[:number].to_s 
          end
         @street = expand_streets(@street)
          street_parts
        end
        @city = []
        if !text[:city].nil?
          @city.push(text[:city])
        else
          @city.push("")
        end
        if !text[:region].nil?
         # @state = []
         @state = text[:region]
          if @state.length > 2
           # full_state = @state.strip # special case: New York
            @state = State[@state]
          end
        elsif !text[:country].nil?
          @state = text[:country]
        elsif !text[:state].nil?
          @state = text[:state]
        end

        @zip = text[:postal_code] 
        @plus4 = text[:plus4] 
        if !@zip
           @zip = @plus4 = ""
        end
      end
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
      strings = []
      if num and num < 100
        [num.to_s, Ordinals[num], Cardinals[num]].each {|replace|
          strings << string.sub(match, replace)
        }
      else
        strings << string
      end
      strings
    end
    
    def parse_zip(regex_match, text)
      idx = text.rindex(regex_match)
      text[idx...idx+regex_match.length] = ""
      text.sub! /\s*,?\s*$/o, ""
      @zip, @plus4 = @zip.map {|s|s.strip} 
      text
    end
    
    def parse_state(regex_match, text)
      idx = text.rindex(regex_match)
      text[idx...idx+regex_match.length] = ""
      text.sub! /\s*,?\s*$/o, ""
      @full_state = @state[0].strip # special case: New York
      @state = State[@full_state]
      text
    end
    
    def parse_number(regex_match, text)
      # FIXME: What if this string appears twice?
      idx = text.index(regex_match)  
      text[idx...idx+regex_match.length] = ""
      text.sub! /^\s*,?\s*/o, ""
      @prenum, @number, @sufnum = @number.map {|s| s and s.strip}
      text
    end
    
    def parse
      text = @text.clone.downcase

      @zip = text.scan(Match[:zip])[-1]
      if @zip
        text = parse_zip($&, text) 
      else
        @zip = @plus4 = ""
      end
      
      @state = text.scan(Match[:state])[-1]
      if @state
        text = parse_state($&, text)
      else
        @full_state = ""
        @state = ""
      end
      
      @number = text.scan(Match[:number])[0]
      # FIXME: 230 Fish And Game Rd, Hudson NY 12534
      if @number # and not intersection?
        text = parse_number($&, text)
      else
        @prenum = @number = @sufnum = ""
      end

      # FIXME: special case: Name_Abbr gets a bit aggressive
      # about replacing St with Saint. exceptional case:
      # Sault Ste. Marie

      # FIXME: PO Box should geocode to ZIP
      @street = text.scan(Match[:street])
      @street = expand_streets(@street)
      # SPECIAL CASE: 1600 Pennsylvania 20050
      @street << @full_state if @street.empty? and @state.downcase != @full_state.downcase      
 
      @city = text.scan(Match[:city])
      if !@city.empty?
        @city = [@city[-1].strip]
        add = @city.map {|item| item.gsub(Name_Abbr.regexp) {|m| Name_Abbr[m]}} 
        @city |= add
        @city.map! {|s| s.downcase}
        @city.uniq!
      else
        @city = []
      end

      # SPECIAL CASE: no city, but a state with the same name. e.g. "New York"
      @city << @full_state if @state.downcase != @full_state.downcase
    end
    
    def expand_streets(street)
      if !street.empty? && !street[0].nil?
        street.map! {|s|s.strip}
        add = street.map {|item| item.gsub(Name_Abbr.regexp) {|m| Name_Abbr[m]}}
        street |= add
        add = street.map {|item| item.gsub(Std_Abbr.regexp) {|m| Std_Abbr[m]}}
        street |= add
        street.map! {|item| expand_numbers(item)}
        street.flatten!
        street.map! {|s| s.downcase}
        street.uniq!
      else
        street = []
      end
      street
    end

    def street_parts
      strings = []
      # Get all the substrings delimited by whitespace
      @street.each {|string|
        tokens = string.split(" ")
        strings |= (0...tokens.length).map {|i|
                   (i...tokens.length).map {|j| tokens[i..j].join(" ")}}.flatten
      }
      strings = remove_noise_words(strings)

      # Try a simpler case of adding the @number in case everything is an abbr.
      strings += [@number] if strings.all? {|s| Std_Abbr.key? s or Name_Abbr.key? s}
      strings.uniq
    end

    def remove_noise_words(strings)
      # Don't return strings that consist solely of abbreviations.
      # NOTE: Is this a micro-optimization that has edge cases that will break?
      # Answer: Yes, it breaks on simple things like "Prairie St" or "Front St"
      prefix = Regexp.new("^" + Prefix_Type.regexp.source + "\s*", Regexp::IGNORECASE)
      suffix = Regexp.new("\s*" + Suffix_Type.regexp.source + "$", Regexp::IGNORECASE)
      predxn = Regexp.new("^" + Directional.regexp.source + "\s*", Regexp::IGNORECASE)
      sufdxn = Regexp.new("\s*" + Directional.regexp.source + "$", Regexp::IGNORECASE)
      good_strings = strings.map {|s|
        s = s.clone
        s.gsub!(predxn, "")
        s.gsub!(sufdxn, "")
        s.gsub!(prefix, "")
        s.gsub!(suffix, "")
        s
      }
      good_strings.reject! {|s| s.empty?}
      strings = good_strings if !good_strings.empty? {|s| not Std_Abbr.key?(s) and not Name_Abbr.key?(s)}
      strings
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
      good_strings = strings.reject {|s| Std_Abbr.key? s}
      strings = good_strings if !good_strings.empty?
      strings.uniq
    end

    def city= (strings)
      # NOTE: This will still fail on: 100 Broome St, 33333 (if 33333 is
      # Broome, MT or what)
      strings = expand_streets(strings) # fix for "Mountain View" -> "Mountain Vw"
      match = Regexp.new('\s*\b(?:' + strings.join("|") + ')\b\s*$', Regexp::IGNORECASE)
      # only remove city from street strings if address was parsed
      unless @text == ""
        @street = @street.map {|string| string.gsub(match, '')}.select {|s|!s.empty?}
      end
    end

    def po_box?
      Match[:po_box].match @text
    end
    
    def intersection?
      Match[:at].match @text
    end
  end
end
