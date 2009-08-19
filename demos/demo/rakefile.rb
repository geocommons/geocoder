require 'rake'

task :boot_env do 
  require 'config/bootstraps'; 
end

namespace :db do
  task :migrate => :connect do
    ActiveRecord::Base.logger = Logger.new(STDOUT)
    ActiveRecord::Migration.verbose = true
    ActiveRecord::Migrator.migrate('db/migrate/', nil)
  end
  
  task :connect => :boot_env do
    BootStraps::Initializer.config.db.connect
  end
end