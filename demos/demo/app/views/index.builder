xml.locations do
  unless @records.nil?
    @records.each do |record|
      xml.location do
        xml.score format("%.2f", record[:score]*100)
        %w{lat lon number prefix pretyp predir prequal street suftyp sufdir sufqual city state zip}.each do |field|
          xml.tag! field, record[field.to_sym]
        end
      end
    end
  end
end

