module Geocoder
end

module Geocoder::US
  class NumberMap < Hash
    def self.[] (array)
      nmap = self.new({})
      array.each {|item| nmap << item } 
      nmap
    end
    def initialize (array)
      @count = 0
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
