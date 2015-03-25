require 'bundler'
Bundler.setup :default, ENV.fetch('RACK_ENV') { 'development' }

require_relative 'app'

run DummyApp
