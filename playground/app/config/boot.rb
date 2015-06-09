$:.unshift(File.expand_path("../../app", File.dirname(__FILE__)))

require 'config/variables'

require 'bundler'
Bundler.setup :default, RACK_ENV

require 'roda'
require 'wedge'

require 'pry'
require 'awesome_print'

class Playground < Roda; end

require 'app'

Dir["#{APP_ROOT}/forms/*.rb"].sort.each { |file| require file }
Dir["#{APP_ROOT}/components/*.rb"].sort.each { |file| require file }
Dir["#{APP_ROOT}/models/*.rb"].sort.each { |file| require file }

require './spec/spec_helper' if RACK_ENV == 'test'
