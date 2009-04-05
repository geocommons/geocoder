require 'geocoder/us/constants'

module Geocoder::US
  Fields = [
    [:prenum,   nil],
    [:number,   /^(\S*[^\s\d])?(\d+)([^\s\d]*)$/o, [:prenum,:number,:sufnum]],
    [:sufnum,   nil],
    [:fraction, /^\d+\/\d+/o],
    [:predir,   Directional],
    [:prequal,  Prefix_Qualifier],
    [:pretyp,   Prefix_Type],
    [:street,   /^[\w\.\-]+(?: [\w\.\-]+){0,4}$/o],
    [:suftyp,   Suffix_Type],
    [:sufqual,  Suffix_Qualifier],
    [:sufdir,   Directional],
    [:unittyp,  Unit_Type],
    [:unit,     lambda {|p, tok| p[:unittyp].any? and tok =~ /^\S+$/o}],
    [:city,     /^[a-z\.\-\']{2,}(?: [a-z\.\-\']+){0,4}$/io],
    [:state,    State],
    [:zip,      /^(\d{5})(?:-(\d{4}))?$/o, [:zip,:plus4]],
    [:plus4,    nil]
  ]
  Field_Index = Hash[*((0...Fields.length).map {|i| [Fields[i][0],i]}.flatten)]

  class Parse < Hash
    attr_accessor :state
    attr_accessor :penalty
    def self.new
      parse = self[*(Fields.map {|f,m| [f,""]}.flatten)]
      parse.state   = Fields[0][0]
      parse.penalty = 0
      parse
    end
    def remaining_states
      return [] if @state.nil? or Field_Index[@state].nil?
      Fields[Field_Index[@state]...Fields.length]
    end
    def next_state!
      remain = remaining_states[1]
      @state = remain.nil? ? nil : remain[0]
    end
    def test? (match, value)
      if match.respond_to? "partial?"
        match.partial? value
      elsif match.respond_to? "match"
        match.match value
      elsif match.respond_to? "call"
        match.call self, value
      else
        false
      end
    end
    def skip
      no_parse = clone
      no_parse.penalty += 1
      return no_parse
    end
    def extend (state, match, token)
      if match.nil? or token == ","
        next_state!
        return self
      end
      if fetch(state).any?
        value = fetch(state) + " " + token
      else
        value = token
      end
      if test? match, value
        new_parse = clone
        new_parse[state] = value
        new_parse.state = state
        return new_parse
      end
      return nil
    end
    def substitute!
      for field, match, groups in Fields
        next if fetch(field).empty?
        if match.respond_to? "key?"
          value = fetch(field)
          store field, match[value] if match.key? value
        elsif match.is_a? Regexp and not groups.nil?
          submatch = fetch(field).scan(match)[0]
          unless submatch.nil?
            submatch.zip(groups).each {|v,k| store(k, v) unless v.nil?}
          end
        end
      end
    end
    def score
      select {|k,v| v != ""}.length - penalty
    end
  end

  class Address
    attr :text
   
    def initialize (text)
      @text = text
    end

    def clean (value)
      value.gsub(/[^a-z0-9 '#\/-]+/io, "")
    end
    def tokens
      @text.split(/(,)?\s+/o).map{|token| clean token} 
    end
    def expand_token (token)
      tokens = [token, Name_Abbr[token]]
      if /^\d/o.match token
        num = token.to_i
      elsif Ordinals[num]
        num = Ordinals[num]
      elsif Cardinals[num]
        num = Cardinals[num]
      end
      tokens += [num.to_s, Ordinals[num], Cardinals[num]] if num and num < 100
      tokens.compact.to_set
    end
    def parse_token (stack, token, max_penalty)
      return stack if token.empty?
      tokens = expand_token token
      output = []
      for parse in stack
        output << parse.skip if parse.penalty < max_penalty
        for state, match in parse.remaining_states
          for item in tokens
            new_parse = parse.extend state, match, item
            output << new_parse if new_parse
          end
        end
      end
      output
    end

    def parse (max_penalty=0, cutoff=10)
      stack = [Parse.new()]
      tokens.each {|token|
        stack = parse_token stack[0...cutoff], token, max_penalty
        stack.sort! {|a,b| b.score <=> a.score}
      }
      stack = stack[0...cutoff]
      stack.each {|parse| parse.substitute!}
    end
  end
end
