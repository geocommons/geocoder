require 'tmpdir'
require 'geocoder/us/database'
require 'gdal/ogr'

require 'rubygems'
require 'zip/zip'

class Geocoder::US::Import < Geocoder::US::Database
  @tables = {}

  def self.tables
    @tables
  end

  def tables
    self.class.tables
  end

  def initialize (filename, options)
    options[:create] = true
    super(filename, options)
    @sqlpath = options[:sql]
    create_tables
  end

  def log (*args)
    $stderr.print *args
  end

  def spin
    @spin ||= 0
    log "|/-\\"[@spin/100..@spin/100]+"\010" if @spin % 100 == 0
    @spin += 1
    @spin %= 400
  end

  def execute_batch (*args)
    @db.execute_batch(*args) 
  end

  def execute_script (file)
    if File.expand_path(file) != file
      file = File.join(@sqlpath, file)
    end    
    execute_batch File.open(file).read
  end

  def load_features(file)
    geoms = []
    dataset = Gdal::Ogr.open(file)
    layer = dataset.get_layer(0)
    field_count = layer.get_layer_defn.get_field_count
    layer.reset_reading
    layer.get_feature_count.times do |i|
      feature = layer.get_feature(i)
      attrs = []
      field_count.times do |j|
        attrs << feature.get_field_as_string(j)
      end
      geom = feature.get_geometry_ref
      subgeom = geom.get_geometry_ref(0) if geom
      geom = subgeom if subgeom
      if geom
        points = []
        geom.get_point_count.times do |v|
          points << (geom.get_x(v)*1_000_000).to_i
          points << (geom.get_y(v)*1_000_000).to_i
        end
        geom = points.pack("V*")
      end
      yield attrs, geom
    end
  end

  def insert_data (st, table, attrs)
    unless st
     values = placeholders_for attrs
     st = @db.prepare("INSERT INTO #{table} VALUES (#{values});")
    end
    st.execute(attrs)
  end

  def insert_shapefile (file, table)
    st = nil
    load_features(file) do |attrs, geom|
      attrs << SQLite3::Blob.new(geom) if geom
      insert_data st, table, attrs
    end
  end

  def insert_csv (file, table, delimiter="|")
    st = nil
    File.open(file).readlines.each do |line|
      attrs = line.chomp.split(delimiter)
      insert_data st, table, attrs
    end
  end

  def make_temp_dir (cleanup=true)
    path = File.join(Dir.tmpdir, "geocoder-#{$$}")
    FileUtils.mkdir_p path
    if block_given?
      begin
        yield path
      ensure
        FileUtils.rm_r(path) if cleanup
      end
    else
      path
    end
  end

  def unpack_zip (file, path)
    # log "- unpacking #{file}"
    Zip::ZipFile.open(file).each do |entry|
      target = File.join(path, entry.name)
      # log "  - #{target}"
      entry.extract target
    end
  end

  def import_zip (zipfile, table)
    make_temp_dir do |tmpdir|
      unpack_zip zipfile, tmpdir
      basename = File.join(tmpdir, File.basename(zipfile))[0..-5]
      shpfile = basename + ".shp"
      shpfile = basename + ".dbf" unless File.exists? shpfile
      if File.exists? shpfile
        log "#{table} "
        insert_shapefile shpfile, table
      else
        log "\nNOT FOUND: #{shpfile}\n"
      end
    end 
  end

  def import_path (path)
    log "\n#{path}: "
    execute_script "setup.sql"
    @db.transaction do
      tables.each do |table, glob|
        file = Dir[File.join(path, glob)][0]
        next unless file
        if file =~ /\.zip$/io
          import_zip file, table
        else
          import_shapefile file, table
        end
      end
    end
    execute_script "convert.sql"
  end

  def import_tree (root)
    if Dir[File.join(root, tables.values[0])].any?
        import_path root
    else
      Dir[File.join(root, "*")].sort.each do |file|
        import_tree file if File.directory? file
      end
    end
  end

  def create_tables
    uninit = false
    begin
      @db.execute("SELECT 0 FROM place")
    rescue SQLite3::SQLException
      uninit = true
    end
    if uninit
      log "creating tables\n"
      execute_script "create.sql"
      post_create
    end
  end

  def post_create
  end
end

class Geocoder::US::Import::TIGER < Geocoder::US::Import
  @tables = {:tiger_edges     => "*_edges.zip", 
             :tiger_featnames => "*_featnames.zip",
             :tiger_addr      => "*_addr.zip"}
  def post_create
    log "importing places"
    @db.transaction do
      insert_csv File.join(@sqlpath, "place.csv"), "place"
    end
  end
end

db = Geocoder::US::Import::TIGER.new(ARGV[0], :sql => "sql")
ARGV[1..ARGV.length].each do |path|
  db.import_tree path
end
