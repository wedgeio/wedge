if RUBY_ENGINE == 'opal'
  require 'wedge'
  require 'opal-rspec'
  require 'opal/jquery'
  require 'opal/jquery/rspec'
else
  ENV['RACK_ENV'] ||= 'test'

  $:.unshift(File.expand_path("../lib", File.dirname(__FILE__)))
  $:.unshift(File.expand_path("../playground", File.dirname(__FILE__)))

  # this is so it doesn't throw an error because we use opal/jquery/rspec which
  # adds an html method client side.
  module RSpecHelpers
    def html(_); end
  end

  RSpec.configure do |config|
    config.extend RSpecHelpers
  end

  require 'app/config/boot'
end
