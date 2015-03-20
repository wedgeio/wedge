require 'minitest/autorun'
require 'browserio'

require 'pry'
require 'awesome_print'

module Minitest
  class Test
    extend Minitest::Spec::DSL

    def session
      @_session ||= OpenStruct.new
    end

    def bio(*args)
      BrowserIO[*args]
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
