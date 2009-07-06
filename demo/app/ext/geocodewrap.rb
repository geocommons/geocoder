require 'rubygems'
require 'geocoder/us/database'

module Sinatra
  module GeocodeWrap
    attr_accessor :db
    def self.registered(app)
       @@db = Geocoder::US::Database.new("/opt/tiger/geocoder.db")
       app.get '/' do
     	 unless params[:address].nil?
           @records = @@db.geocode params[:address]
   	 end

	 case params[:format]
	 when /xml/
	  builder :index
	 when /atom/
	  builder :atom
	 when /json/
	   @records.to_json
 	 else
	   erb :index
	 end
       end
       app.post '/batch' do
	 csv_file = request.env["rack.input"].read
	 csv = FasterCSV.parse(csv_file, :row_sep => "*", :col_sep => "|")
	 headers = csv[0]
	 @records = csv.collect do |record|
	   next if record == headers
           begin
	     puts record[1]
	    (@@db.geocode record[1]).first.merge(headers[0] => record[0])
           rescue Exception => e
	    puts e.message
            next
	   end
         end.compact
         case params[:format]
	 when /xml/
	   builder :index
	 when /atom/
	   builder :atom
	 when /json/
	   @records.to_json
	 else
	   erb :index
	 end 

       end
    end
    
 
  end
  register GeocodeWrap
end
