
BootStraps::Initializer.configure do |config|
  
  #Use the vendor directory
  config.vendored = true
  config.default_env = 'production'
  
  config.gem 'activerecord'
  config.gem 'sinatra'
  config.gem 'fastercsv'
  config.gem 'json'
  
  
  config.db.connect_action do
    ActiveRecord::Base.establish_connection( :adapter => 'sqlite3', 
                                             :dbfile =>  File.join(config.root, 'db', "#{config.env}.sqlite3"),
                                             :wait_timeout => 0.15,
                                             :timeout => 250)
  end

  config.framework.set :root, config.root
  config.framework.set :environment, config.env
  config.framework.set :raise_errors, true
  config.framework.set :views, File.join('app','views')
  config.framework.set :server, 'mongrel'
  config.framework.set :static, true
  config.framework.set :logging, false
  config.framework.set :port, 4567
  config.framework.set :lock, false  

end
