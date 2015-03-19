require 'browserio/config'

module BrowserIO
  class Component
    class << self
      attr_accessor :config

      def setup(&block)
        @config ||= Config.new(klass: self)

        block.call config

        components[settings[:name]] = config
      end

      def components
        Thread.current[:_browser_io_components] ||= {}
      end

      def settings
        config.settings
      end
    end
  end
end
