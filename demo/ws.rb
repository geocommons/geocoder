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
  when /xml/
    builder :index
  when /atom/
    builder :atom
  else
    erb :index
  end
end

require "yaml"
post '/batch' do 
  FileUtils.mkdir_p('uploads/')
  FileUtils.mv(params[:uploaded_csv][:tempfile].path, "uploads/#{params[:uploaded_csv][:filename]}")  
  csv_file = "uploads/#{params[:uploaded_csv][:filename]}"
  db = Geocoder::US::Database.new("/mnt/tiger2008/geocoder.db")
  csv = FasterCSV.parse(open(csv_file))
  headers = csv[0]
  
  @records = csv.collect do |record|
    next if record == headers
    begin
      (db.geocode record[1]).first
    rescue Exception => e
      puts e.message
      next
    end
  end.compact
  puts @records.to_yaml
  case params[:format]
  when /atom/
    builder :index
  else
    erb :index
  end
  
end


