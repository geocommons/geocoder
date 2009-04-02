module Geocoder
end

module Geocoder::US
  class NumberMap < Hash
    def self.[] (array)
      nmap = new()
      array.each {|item| nmap << item } 
      nmap
    end
    def initialize (array)
      @count = 0
    end
    def <<(item)
      store item, @count
      store @count, item
      @count += 1
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
    Cardinals[1..9].each {|ones| Cardinals << tens + "-" + ones}
  }


  Ordinals = NumberMap[%w[
    zeroth first second third fourth fifth sixth seventh eighth ninth
    tenth eleventh twelfth thirteenth fourteenth fifteenth sixteenth
    seventeenth eighteenth nineteenth
  ]]
  Cardinal_Tens.each {|tens|
    Ordinals << tens.gsub("y","ieth")
    Ordinals[1..9].each {|ones| Ordinals << tens + "-" + ones}
  }
end
