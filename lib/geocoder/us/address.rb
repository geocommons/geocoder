require 'geocoder/us/constants'

module Geocoder::US
  # Defines the matching of parsed address tokens.
  Match = {
    :number   => /^(\S*[^\s\d])?(\d+)([^\s\d]*)$/o,
    :abbr     => Std_Abbr,
    :street   => /^(?:\d+\w*|[a-z'-]+)$/io,
    :city     => /^[a-z'-]+$/io,
    :state    => State,
    :zip      => /^(\d{5})(?:-(\d{4}))?$/o,
    :at       => /^(?:at|@|and|&)$/io,
    :comma    => /^,$/o
  }
 
  # The Address class takes a US street address or place name and
  # constructs a list of possible structured parses of the address
  # string.
  class Address
    attr :text
    attr :tagged
   
    # Takes an address or place name string as its sole argument.
    def initialize (text)
      @text = text
      parse
    end

    # Removes any characters that aren't strictly part of an address string.
    def clean (value)
      value.gsub(/[^a-z0-9 ,'#\/-]+/io, "")
    end

    # Tokenizes the input text on commas and whitespace, and cleans
    # each token.
    def tokenize
      @text.strip.split(/(,)?\s+/o) \
                 .select {|token| token.any?} \
                 .map {|token| clean token} 
    end

    private

    def match (test, token)
      return ((test.respond_to? "partial?" and test.partial? token) \
           or (test.respond_to? "match" and test.match token))
    end

    def tag
      tokenize.map {|token|
        item = [token]
        Match.each {|tag, test|
          item << tag if match test, token
        }
        item
      }
    end

    def prune (tags)
      Match.keys.each {|test|
        method = "prune_#{test}"
        tags = send method, tags if respond_to? method, true
      }
      tags
    end

    def prune_number (tags)
      # Find the first number and prune everything after it.
      idx = (0...tags.length).find {|j| tags[j].member? :number}
      tags[idx+1...tags.length] = \
        tags[idx+1...tags.length].map {|tag| tag - [:number]} if idx
      tags
    end

    def prune_zip (tags)
      # Find the last ZIP and prune everything before it.
      idx = (0...tags.length).to_a.reverse.find {|j| tags[j].member? :zip}
      tags[0...idx] = tags[0...idx].map {|tag| tag - [:zip]} if idx
      tags
    end

    def prune_multitag (test, dist, tags)
      i = 0
      while i < tags.length
        i += 1 and next unless tags[i].member? test
        if strings(test, tags[i..i+dist]).any? {|str| Match[test].key? str}
          # FIXME: dist might not actually be the matching distance
          print "Accepting #{tags[i]} as #{test}\n"
          i += dist
        else
          print "Rejecting #{tags[i]} as #{test}\n"
          tags[i] -= [test]
          i += 1
        end
      end
      tags
    end

    def prune_abbr (tags)
      prune_multitag :abbr, 3, tags
    end

    def prune_state (tags)
      prune_multitag :state, 2, tags
    end

    # Expands a token into a list of possible strings based on
    # the Geocoder::US::Name_Abbr constant, and expands numerals and
    # number words into their possible equivalents.
    public

    def expand_token (token)
      token_list = [token]
      [Name_Abbr, Std_Abbr].each {|hash|
        if hash.key? token and hash[token].downcase != token.downcase
          token_list.unshift hash[token]
        end
      }
      if /^\d+(?:st|nd|rd|th)?$/o.match token
        num = token.to_i
      elsif Ordinals[token]
        num = Ordinals[token]
      elsif Cardinals[token]
        num = Cardinals[token]
      end
      token_list = [num.to_s, Ordinals[num], Cardinals[num]] if num and num < 100
      token_list.sort! {|a,b| a.length <=> b.length} if token_list.length > 1
      token_list.compact
    end

    private

    def parse
      tags = prune tag
      tags.each {|tag| tag[0..0] = expand_token tag[0]}
      @tagged = tags
    end

    def strings (tag, list=nil)
      list = @tagged if list.nil?
      return [] if list.empty?
      result = []
      matches = (0...list.length).select{|i| list[i].member? tag}
      while matches.any?
        idx = matches.shift
        tokens = list[idx].reject{|t| t.is_a? Symbol}
        stop = matches.inject(idx) {|i,j| i+1 == j ? j : i}
        tokens.each {|token|
          result << token
          strings(tag, list[idx+1..stop]).each {|rest|
            result << token + " " + rest
            } if stop and stop > idx
        }
      end
      result
    end

    def fix_tags (type, string)
      tokens = string.split(" ")
      @tagged.map! {|tag|
        if tag.member? type and (tag & tokens).empty?
          tag - [type]
        else
          tag
        end
      }
    end

    public
  
    def city
      if @city.nil?
        @city = strings :city 
        @city.reverse!
      end
      @city
    end
  
    def city= (string)
      fix_tags :city, string
      @street = @city = nil
    end

    def state
      if @state.nil?
        @state = strings :state
        if @state.any?
          @state.sort! {|a,b| b.length <=> a.length}
          @state = State[@state[0]]
        else
          @state = ""
        end
      end
      @state
    end

    def state= (string)
      fix_tags :state, string
      @street = @city = @state = nil
    end

    def zip
      if @zip.nil?
        @zip = strings(:zip)
        @zip = @zip.any? ? @zip[0] : ""
      end
      @zip
    end

    def number
      if @number.nil?
        number = strings(:number)
        if number.any?
          @prenum, @number, @sufnum = number[0].scan(Match[:number])[0]
        else
          @number = @prenum = ""
        end
      end
      @number
    end

    def prenum
      number and @prenum
    end

    def street
      if @street.nil?
        unreserved = @tagged.reject {|tag|
          tag.any? {|x| x.is_a? Symbol and x != :street}
        }
        if unreserved.any?
          @street = strings :street, unreserved
        else
          @street = strings(:street)
        end
        #@street.sort! {|a,b| b.length <=> a.length}
      end
      @street
    end

    def intersection?
      @tagged.any? {|tag| tag.any? {|t| t == :at}}
    end

    def intersection!
      @tagged.map! {|tag| tag - [:number]}
    end

    def panic!
      @tagged.map! {|tag| tag << :panic}
      @street = nil
    end
  end
end
