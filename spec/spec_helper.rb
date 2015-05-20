if RUBY_ENGINE == 'opal'
  require 'wedge'
  require 'opal-rspec'
  require 'opal/jquery'
else
  ENV['RACK_ENV'] ||= 'test'

  $:.unshift(File.expand_path("../lib", File.dirname(__FILE__)))
  $:.unshift(File.expand_path("../playground", File.dirname(__FILE__)))

  require 'app/config/boot'
end
