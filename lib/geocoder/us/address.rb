require 'geocoder/us/constants'

module Geocoder::US
  Fields = [
    [:prenum,   nil],
    [:number,   /^(\S*[^\s\d])?(\d+)([^\s\d]*)$/o, [:prenum,:number,:sufnum]],
    [:sufnum,   nil],
    [:fraction, /^\d+\/\d+/o],
    [:predir,   Directional],
    [:prequal,  Pre_Qualifier],
    [:pretyp,   Pre_Type],
    [:street,   /^[\w\.\-]+(?: [\w\.\-]+){0,4}$/o],
    [:suftyp,   Suf_Type],
    [:sufqual,  Suf_Qualifier],
    [:sufdir,   Directional],
    [:unittyp,  Unit_Type],
    [:unit,     lambda {|p, tok| p[:unittyp].any? and tok =~ /^\S+$/o}],
    [:city,     /^[a-z\.\-\']{2,}(?: [a-z\.\-\']+){0,4}$/io],
    [:state,    State],
    [:zip,      /^(\d{5})(?:-(\d{4}))?$/o, [:zip,:plus4]],
    [:plus4,    nil]
  ]
  Field_Index = Hash[(0...Fields.length).map {|i| [Fields[i][0],i]}]

  class Parse < Hash
    attr_accessor :state
    attr_accessor :penalty
    def self.new
      parse = self[Fields.map {|f,m| [f,""]}]
      parse.state   = :number
      parse.penalty = 0
      parse
    end
    def remaining_states
      return [] if @state.nil? or Field_Index[@state].nil?
      Fields[Field_Index[@state]...Fields.length]
    end
    def next_state!
      return nil if @state.nil?
      current = Field_Index[@state]
      if current.nil? or current + 1 >= Fields.length
        @state = nil
      elsif
        @state = Fields[current + 1][0]
      end
    end
    def test? (match, value)
      if match.respond_to? "partial?"
        match.partial? value.gsub(/[^\w ]+/o, "").downcase
      elsif match.respond_to? "key?"
        match.key? value.gsub(/[^\w ]+/o, "").downcase
      elsif match.respond_to? "match"
        match.match value
      elsif match.respond_to? "call"
        match.call self, value
      else
        false
      end
    end
    def score
      select {|k,v| v != ""}.length - penalty
    end
    def substitute!
      for field, match, groups in Fields
        if match.respond_to? "key?"
          value = fetch(field).gsub(/[^\w ]/o, "").downcase
          store field, match[value] if match.key? value
        elsif match.is_a? Regexp and not groups.nil?
          submatch = fetch(field).scan(match)[0]
          unless submatch.nil?
            submatch.zip(groups).each {|v,k| store(k, v) unless v.nil?}
          end
        end
      end
    end
  end

  class Address
    attr :text
   
    def initialize (text, max_penalty=1)
      @text = text
      @max_penalty = max_penalty
    end

    def tokens
      @text.split /(,)?\s+/o
    end

    def parse_token (stack, token)
      return stack if token.empty?
      print "token: ", token, " "
      if token == ","
        stack.each {|parse| parse.next_state!}
        print stack.length, "\n";
        return stack
      end
      output = []
      for parse in stack
        if parse.penalty < @max_penalty
          no_parse = parse.clone
          no_parse.penalty += 1
          output << no_parse
        end
        for state, match in parse.remaining_states
          if parse[state].any?
            value = parse[state] + " " + token
          else
            value = token
          end
          if parse.test? match, value
            new_parse = parse.clone
            new_parse[state] = value
            new_parse.state = state
            output << new_parse
          end
        end
      end
      print output.length, "\n";
      output
    end

    def parse
      stack = [Parse.new()]
      tokens.each {|token|
        stack = parse_token stack[0..10], token
        stack.sort! {|a,b| b.score <=> a.score}
      }
      stack.each {|parse| parse.substitute!}
      stack
    end
  end
end
