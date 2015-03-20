module BrowserIO
  class Component
    class << self
      # Stores the config instance.
      #
      # @return [Config]
      attr_accessor :config

      # Used to setup the component with default options.
      #
      # @example
      #   class SomeComponent < Component
      #     setup do |config|
      #       config.name :some
      #     end
      #   end
      # @yield [Config]
      def setup(&block)
        @config ||= Config.new(klass: self)

        block.call config

        components[opts[:name]] = opts
      end

      # Shortcut for BrowserIO.components
      #
      # @return [Hash, BrowserIO.components]
      def components
        BrowserIO.components ||= {}
      end

      # Shortcut for the Config#opts
      #
      # @return [Openstruct, Config#opts]
      def opts
        config.opts
      end
    end
  end
end
