require File.expand_path '../variables', __FILE__

begin
  # use `bundle install --standalone --binstubs .bundle/bin' to get this...
  require_relative '../.bundle/bundler/setup'
rescue LoadError
  # fall back to regular bundler if the developer hasn't bundled standalone
  require 'bundler'
  Bundler.setup :default, RACK_ENV
end

require 'roda'
require 'wedge'

require 'pry'
require 'awesome_print'

class Playground < Roda; end

require_relative '../app'

Dir["#{APP_ROOT}/forms/*.rb"].sort.each { |file| require file }
Dir["#{APP_ROOT}/components/*.rb"].sort.each { |file| require file }
