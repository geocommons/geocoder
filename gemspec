Gem::Specification.new do |s|
    s.name          = 'Geocoder-US'
    s.version       = "2.0.0"
    s.author        = "Schuyler Erle"
    s.email         = 'geocoder@entropyfree.com'
    s.description   = "US address geocoding based on TIGER/Line."
    s.summary       = "US address geocoding based on TIGER/Line."
    s.homepage      = "http://geocoder.us/"
    s.files         = ["lib/geocoder/us.rb"] + Dir["lib/geocoder/us/*"] + Dir["tests/*"]
    s.require_path  = "lib"
    s.test_files    = "tests/run.rb"
    s.has_rdoc      = true
    s.extra_rdoc_files  =   ["README"]
end
