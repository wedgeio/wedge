require 'bundler'
Bundler.setup :default, ENV.fetch('RACK_ENV') { 'development' }

require 'minitest/autorun'
require 'minitest/reporters'
require 'wedge'

require 'pry'
require 'awesome_print'

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new # spec-like progress

module Minitest
  class Test
    extend Minitest::Spec::DSL

    def session
      @_session ||= OpenStruct.new
    end

    def wedge(name, *args, &block)
      Wedge[name, nil, *args, &block]
    end

    # def app(*args)
    #   a = Class.new(PropertyLink).new
    #
    #   a.instance_variable_set(:@_request, OpenStruct.new(
    #     session: session,
    #     env: {
    #       'rack.session' => {}
    #     }
    #   ))
    #
    #   a.component(*args)
    # end
  end
end
