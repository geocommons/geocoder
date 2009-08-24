require 'rubygems'
require 'geocoder/us/database'
require 'logger'

module Sinatra
  module GeocodeWrap
    attr_accessor :db
    def self.registered(app)
      options = {:cache_size => 100000}
       @@db = Geocoder::US::Database.new("/Users/katechapman/usgeocode.db", options)
       stats = Logger.new("geocoderstats.log", 10, 1024000)
       app.get '/' do
     	   unless params[:address].nil?
           begin
             @records = @@db.geocode params[:address]
             stats.debug "Geocoded: 1, Failed: 0, Geocoded At: " << DateTime.now.to_s
   	       rescue Exception => e
   	         stats.debug "Geocoded: 1, Failed: 1, Geocoded At: " << DateTime.now.to_s
   	         puts e.message
   	       end
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
         failed_codes = 0
         total_codes = 0
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
       	    total_codes += 1
       	  next if record == headers
            begin
       	      result = @@db.geocode record[1]
       	      if result.empty?
       	         result[0] = {:lon => nil, :lat => nil, :precision => 'unmatched', :score => 0}   
       	         failed_codes += 1 
       	      end
       	      result.first.merge(headers[0] => record[0])
            rescue Exception => e
              failed_codes += 1 
       	      puts e.message
              next
       	     end
             end.compact
            puts Time.now
            stats.debug "Geocoded: " << total_codes.to_s << ", Failed: " << failed_codes.to_s << ",Geocoded At: " << DateTime.now.to_s
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
