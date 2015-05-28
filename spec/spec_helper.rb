require 'wedge'

if RUBY_ENGINE == 'opal'
  require 'opal/rspec'
  require 'opal/jquery/rspec'
else

  ENV['RACK_ENV'] ||= 'test'

  $:.unshift(File.expand_path("../lib", File.dirname(__FILE__)))
  $:.unshift(File.expand_path("../playground/app", File.dirname(__FILE__)))

  # this is so it doesn't throw an error because we use opal/jquery/rspec which
  # adds an html method client side.
  module RSpecHelpers
    def html(_); end
  end

  RSpec.configure do |c|
    c.extend RSpecHelpers
    c.filter_run_excluding :slow
  end

  require 'config/boot'
end
