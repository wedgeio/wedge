require 'wedge'

if RUBY_ENGINE == 'opal'
  require 'opal/rspec'
  require 'opal/jquery/rspec'
else
  require 'rspec'

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
    c.color = true
    # c.before do
    #   allow(Playground::User).to receive(:find) do |id|
    #     if id == 1
    #       {id: 1, first_name: 'Test', last_name: 'Admin', is_admin: true}
    #     else
    #       nil
    #     end
    #   end
    # end
  end

  require 'config/boot'

  Dir["./spec/stubs/**/*.rb"].sort.each { |file| require file }
end
