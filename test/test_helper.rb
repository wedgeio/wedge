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
      name = args.shift
      component = Thread.current[:_browser_io_components][name.to_sym]
      component.settings.klass.new(*args)
      # require 'pry'
      # binding.pry
      # 'moo'
      # a = Class.new(PropertyLink).new
      #
      # a.instance_variable_set(:@_request, OpenStruct.new(
      #   session: session,
      #   env: {
      #     'rack.session' => {}
      #   }
      # ))
      #
      # a.component(*args)
    end
  end
end
