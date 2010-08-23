require 'sinatra'
disable :run, :reload
require 'geocoder/us/rest'
run Sinatra::Application
