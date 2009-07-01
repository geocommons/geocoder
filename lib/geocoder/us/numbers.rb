module Geocoder
end

module Geocoder::US
  # The NumberMap class provides a means for mapping ordinal
  # and cardinal number words to digits and back.
  class NumberMap < Hash
    attr_accessor :regexp
    def self.[] (array)
      nmap = self.new({})
      array.each {|item| nmap << item } 
      nmap.build_match
      nmap
    end
    def initialize (array)
      @count = 0
    end
    def build_match
      @regexp = Regexp.new(
        '\b(' + keys.flatten.join("|") + ')\b',
        Regexp::IGNORECASE)
    end
    def clean (key)
      key.is_a?(String) ? key.downcase.gsub(/\W/o, "") : key
    end
    def <<(item)
      store clean(item), @count
      store @count, item
      @count += 1
    end
    def [] (key)
      super(clean(key))
    end
  end

  # The Cardinals constant maps digits to cardinal number words and back.
  Cardinals = NumberMap[%w[
    zero one two three four five six seven eight nine ten
    eleven twelve thirteen fourteen fifteen sixteen seventeen
    eighteen nineteen
  ]]
  Cardinal_Tens = %w[ twenty thirty forty fifty sixty seventy eighty ninety ]
  Cardinal_Tens.each {|tens|
    Cardinals << tens
    (1..9).each {|n| Cardinals << tens + "-" + Cardinals[n]}
  }

  # The Ordinals constant maps digits to ordinal number words and back.
  Ordinals = NumberMap[%w[
    zeroth first second third fourth fifth sixth seventh eighth ninth
    tenth eleventh twelfth thirteenth fourteenth fifteenth sixteenth
    seventeenth eighteenth nineteenth
  ]]
  Cardinal_Tens.each {|tens|
    Ordinals << tens.gsub("y","ieth")
    (1..9).each {|n| Ordinals << tens + "-" + Ordinals[n]}
  }
end
