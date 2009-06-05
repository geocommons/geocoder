require 'rubygems'
Gem::manage_gems
require 'rake/gempackagetask'

spec = Gem::Specification.new do |s|
    s.platform      =   Gem::Platform::RUBY
    s.name          = 'Geocoder-US'
    s.version       = "1.0.0"
    s.author        = "Schuyler Erle"
    s.email         = 'geocoder@entropyfree.com'
    s.description   = "US address geocoding based on TIGER/Line."
    s.summary       = "US address geocoding based on TIGER/Line."
    s.homepage      = "http://geocoder.us/"
    s.files         = FileList[
                        'lib/geocoder/*.rb', 'lib/geocoder/us/*.rb', 'tests/*'].to_a
    s.require_path  = "lib"
    s.test_files    = "tests/run.rb"
    s.has_rdoc      = true
    s.extra_rdoc_files  =   ["README"]
end

Rake::GemPackageTask.new(spec) do |pkg|
    pkg.need_tar = true
end

task :default => "pkg/#{spec.name}-#{spec.version}.gem" do
    puts "generated latest version"
end

