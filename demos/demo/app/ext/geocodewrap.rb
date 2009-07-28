require 'rubygems'
require 'geocoder/us/database'

module Sinatra
  module GeocodeWrap
    attr_accessor :db
    def self.registered(app)
     # options = {:cache_size => 50000, :debug => true}
       @@db = Geocoder::US::Database.new("/fortiusone/geocoder/geocoder.db")
       app.get '/' do
     	   unless params[:address].nil?
           begin
             @records = @@db.geocode params[:address]
   	       rescue Exception => e
   	         puts e.message
   	       end
   	      end
           #     puts @records
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
        puts Time.now
       	if params[:uploaded_csv].nil?
                   csv_file = request.env["rack.input"].read
       	    csv = FasterCSV.parse(csv_file, :row_sep => "*", :col_sep => "|")
                else 
       	   FileUtils.mkdir_p('uploads/')
                  FileUtils.mv(params[:uploaded_csv][:tempfile].path, "uploads/#{params[:uploaded_csv][:filename]}")  
                  csv_file = open("uploads/#{params[:uploaded_csv][:filename]}")
                  @filename = params[:uploaded_csv][:filename].gsub(/\.csv/,"")
                  csv = FasterCSV.parse(csv_file)
                end
       	 headers = csv[0]
       	 @records = csv.collect do |record|
       	   next if record == headers
                  begin
       	     
       	   (@@db.geocode record[1]).first.merge(headers[0] => record[0])
           #puts  record    
	      rescue Exception => e
       	    puts e.message
                   next
       	   end
                end.compact
	puts @records
                case params[:format]
       	 when /xml/
       	   builder :index
       	 #  puts Time.now
       	 when /atom/
       	   builder :atom
       	 #  puts Time.now
       	 when /json/
       	 #  puts @records
           @records.to_json
       	  # puts Time.now
       	 else
       	   erb :index
       	   
       	 end 
        # puts Time.now
        end
        
       end
       
        
 
  end
  register GeocodeWrap
end
