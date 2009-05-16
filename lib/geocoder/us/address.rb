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
  Block_State = Field_Index[:street]

  class Parse < Hash
    attr_accessor :state
    attr_accessor :penalty
    def self.new (start_state=nil)
      parse = self[*(Fields.map {|f,m| [f,""]}.flatten)]
      if start_state.nil?
        parse.state = Fields[0][0]
      else
        parse.state = Fields[Field_Index[start_state]][0]
      end
      parse.penalty = 0
      parse
    end
    def inspect
      show = map {|k,v| (v.nil? or v.empty?) ? [] : [k,v]}.flatten
      Hash[*show].inspect
    end
    def remaining_states
      return [] if @state.nil? or Field_Index[@state].nil?
      start = Field_Index[@state]
      stop  = start < Block_State ? Block_State : (Fields.length-1)
      Fields[start..stop]
    end
    def next_state!
      remain = remaining_states[1]
      @state = remain.nil? ? nil : remain[0]
    end
    def test? (match, value)
      result = false
      if match.respond_to? "partial?"
        result = match.partial? value
      elsif match.respond_to? "match"
        result = match.match value
      elsif match.respond_to? "call"
        result = match.call self, value
      end
      return result
    end
    def skip
      no_parse = clone
      no_parse.penalty += 1
      return no_parse
    end
    def completed_state?
      match = Fields[Field_Index[@state]][1]
      return (!match.respond_to?("partial?") or match.key?(fetch(@state)))
    end
    def extend (state, match, token)
      return nil if match.nil? or (state != @state and not completed_state?)
      if token == ","
        return nil unless completed_state?
        new_parse = clone
        new_parse.state = state
        new_parse.next_state!
        return new_parse
      end
      if fetch(state).any?
        value = fetch(state) + " " + token
      else
        value = token
      end
      if test? match, value
        new_parse = clone
        new_parse.state = state
        new_parse[state] = value
        return new_parse
      end
      return nil
    end
    def substitute!
      for field, match, groups in Fields
        next if fetch(field).empty?
        if match.respond_to? "key?"
          value = fetch(field)
          store(field, match[value].to_s) if match.key? value
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
      value.gsub(/[^a-z0-9 ,'#\/-]+/io, "")
    end
    def tokens
      @text.strip.split(/(,)?\s+/o).map{|token| clean token} 
    end
    def expand_token (token)
      if Name_Abbr.key? token and Name_Abbr[token].downcase != token.downcase
        token_list = [Name_Abbr[token], token]
      else
        token_list = [token]
      end
      if /^\d+(?:st|nd|rd)?$/o.match token
        num = token.to_i
      elsif Ordinals[token]
        num = Ordinals[token]
      elsif Cardinals[token]
        num = Cardinals[token]
      end
      token_list = [num.to_s, Ordinals[num], Cardinals[num]] if num and num < 100
      token_list.compact
    end
    def parse_token (stack, token, max_penalty)
      return stack if token.empty?
      token_list = expand_token token
      output = []
      for parse in stack
        output << parse.skip if parse.penalty < max_penalty
        for state, match in parse.remaining_states
          for item in token_list
            new_parse = parse.extend state, match, item
            output << new_parse if new_parse
          end
        end
      end
      output
    end

    def deduplicate (parse_list)
      # can't just stick the parses in a hash because
      # ... you can't use Hashes as hash keys in Ruby and get sensible results
      seen = {}
      deduped = []
      parse_list.each {|p|
        key = p.values_at(*Fields.map{|f| f[0]}).join("|")
        deduped << p unless seen.key? key
        seen[key] = true 
      }
      deduped
    end

    def parse (max_penalty=0, cutoff=10, start_state=nil)
      stack = [Parse.new(start_state)]
      tokens.each {|token|
        stack = parse_token stack[0...cutoff], token, max_penalty
        stack.sort! {|a,b| b.score <=> a.score}
      }
      stack.delete_if {|parse| not parse.completed_state?}
      stack = stack[0...cutoff]
      stack.each {|parse| parse.substitute!}
      stack = deduplicate stack
      stack
    end

    def parse_as_place (max_penalty=0, cutoff=10)
      parse(max_penalty, cutoff, :city)
    end
  end
end
