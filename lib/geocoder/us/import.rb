require 'tmpdir'
require 'geocoder/us/database'

require 'rubygems'
require 'geo_ruby'
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

  def load_features (file)
    dataset = GeoRuby::Shp4r::ShpFile.open(file)
    fields  = dataset.fields
    dataset.each do |record|
      attrs = record.data.values_at(fields)
      geom = record.geometry
      geom = geom.geometries[0] \
        if geom.kind_of? GeoRuby::SimpleFeatures::GeometryCollection
      points = geom.points.map {|x| (x*1_000_000).to_i}
      coords = points.pack("V*")
      yield attrs, coords
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
