require File.expand_path '../variables', __FILE__

require 'roda'
require 'wedge'

require 'pry'
require 'awesome_print'

class Playground < Roda; end

require_relative '../app'

Dir["#{APP_ROOT}/forms/*.rb"].sort.each { |file| require file }
Dir["#{APP_ROOT}/components/*.rb"].sort.each { |file| require file }
