require 'rubygems'

module BootStraps

  class Framework 

    def initialize 
      @methods = {}
    end
    
    def apply_settings!(app)
      @methods.each_pair do |method, calls|
        calls.each do |arg_set|
          app.send(method, *arg_set)
        end
      end
    end
    
    def method_missing(method, *args)
      @methods[method] ||= []
      @methods[method] << args
    end
  end


  class DataStore 
    def connect_action(&block)
      @connect_action = block
    end

    #TODO raise UndefinedConnectAction
    def connect
      @connect_action.call if @connect_action
    end
  end
  
  class Configuration
    attr_accessor :db, :global, :default_env, :vendor_dir, :lib_paths, :framework, :vendored
    attr_reader :gems

    def initialize
      @framework = Framework.new
      @gems = {}
      @global = {}
      @default_env = 'production'
      @vendor_dir = File.join(root, 'vendor')
      @lib_paths = []
      @vendored = false
    end

    def env 
      ENV['RACK_ENV'] ||= default_env 
    end
    
    def env=(val)
      ENV['RACK_ENV'] = val
    end

    def root
      File.join(File.expand_path(File.dirname(__FILE__)), "..")
    end
    
    def gem(*args)
      gem = args.first
      ver = args.last

      @gems[gem] = ver
        
      #its concievable that vendored could be changed mid config
      use_vendor if vendored
      Kernel.send(:gem, *args)
      require gem
    end

    private
    def use_vendor
      Gem.clear_paths
      prepend_gem_path!(File.join(root, 'vendor'))
    end
    
    def prepend_gem_path!(path)
      ENV['GEM_PATH'] = path
    end  
  end

  class Initializer
    @@config = Configuration.new
    class << self
      def configure
        unless @@config.frozen?
          yield @@config
          @@config.freeze
        end
      end

      def config
        @@config
      end 
      
      def boot!
        require File.join(@@config.root, 'config', 'geoenvironment.rb')
        require_libs
      end


      private      
      def require_libs
        [
         subdir_expansion('lib'), 
         subdir_expansion(File.join('app','ext'))
        ].each do |p|
          require_all(p)
        end
      end

      def require_all(path)
        Dir[path].each { |f| require f }
      end 

      def subdir_expansion(subdir)
        File.join(@@config.root, subdir, '**', '*.rb')
      end
    end
  end
end

BootStraps::Initializer.boot!
Straps = BootStraps::Initializer.config


