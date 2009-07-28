require 'rubygems'
require 'sinatra'
require 'geocoder/us/database'
require 'fastercsv'
require 'json'

set :port, 8080
@@db = Geocoder::US::Database.new("/fortiusone/geocoder/geocoder.db")
get '/' do
  unless params[:address].nil?
    @records = @@db.geocode params[:address]
  end

  case params[:format]
  when /xml/
    builder :index
  when /atom/
    builder :atom
  else
    erb :index
  end
end

require 'open-uri'
get '/link.:format' do 
  if(params.include?(:url))
	csv_file = params[:url]
  else
  csv_file = "uploads/#{params[:filename]}.csv"
end
  csv = FasterCSV.parse(open(csv_file))
  headers = csv[0]
  
  @records = csv.collect do |record|
    next if record == headers
    begin
      (@@db.geocode record[1]).first
    rescue Exception => e
      puts e.message
      next
    end
  end.compact
  case params[:format]
  when /atom/
    builder :atom
  when /xml/
    builder :index
  else
    erb :index
  end
  
end


post '/batch' do 
  csv_file = request.env["rack.input"].read
  csv = FasterCSV.parse(csv_file, :row_sep => "*", :col_sep => "|")
  headers = csv[0]
  @records = csv.collect do |record|
  next if record == headers
    begin
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

  



