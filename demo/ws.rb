require 'rubygems'
require 'sinatra'
require 'geocoder/us/database'
require 'fastercsv'

set :port, 8080

get '/' do
  unless params[:address].nil?
    db = Geocoder::US::Database.new("/mnt/tiger2008/geocoder.db")
    @records = db.geocode params[:address]
  end

  case params[:format]
  when /atom/
    builder :index
  else
    erb :index
  end
end

get '/batch' do 
  FileUtils.mkdir_p('uploads/')
  FileUtils.mv(params[:uploaded_csv][:tempfile].path, "uploads/#{params[:uploaded_csv][:filename]}")  
  csv = "uploads/#{params[:uploaded_csv][:filename]}"
  db = Geocoder::US::Database.new("/mnt/tiger2008/geocoder.db")
  csv = FasterCSV.parse(open(csv_file))
  headers = csv[0]
  
  @records = csv.collect do |record|
    next if record == headers
    begin
      (db.geocode record[1]).first
    rescue
      next
    end
  end
  
  case params[:format]
  when /atom/
    builder :index
  else
    erb :index
  end
  
end


