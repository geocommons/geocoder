require 'geocoder/us/import'

class Geocoder::US::Import::TIGER < Geocoder::US::Import
  @tables = {:tiger_edges     => "*_edges.zip", 
             :tiger_featnames => "*_featnames.zip",
             :tiger_addr      => "*_addr.zip"}
  def post_create
    log "importing places"
    @db.transaction do
    #  insert_csv File.join(@sqlpath, "place.csv"), "place"
    end
  end
end
