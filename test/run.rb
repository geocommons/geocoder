#!/usr/bin/ruby 

$LOAD_PATH << File.dirname(__FILE__)
$LOAD_PATH << File.dirname(__FILE__) + "/../lib"
puts "Loadpath=#{$LOAD_PATH.inspect}"
require 'test/unit'
require 'numbers'
require 'constants'
require 'address'
require 'database'

