xml.feed "xmlns" => "http://www.w3.org/2005/Atom", 
"xmlns:georss" => "http://www.georss.org/georss" do
  xml.title "Geocoding results"
  unless @records.nil?
    @records.each do |record|
      xml.entry do
        xml.title %w{prefix pretyp predir prequal street suftyp sufdir sufqual city state zip}.collect {|f| record[f.to_sym}}.compact.join(",")
        xml << "<georss:point>#{record[:lat]} #{record[:lon]}</georss:point>"
      end
    end
  end
end
