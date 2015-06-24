class Roda
  module RodaPlugins
    class WedgePlugin
      def self.configure(app, opts = {})
        app.use Wedge::Middleware, opts
      end

      module ClassMethods
        def wedge_plugin name, settings = {}, &block
          Wedge.plugin name, settings, &block
        end
      end

      module InstanceMethods
        def wedge(name, *args, &block)
          Wedge.scope!(self)[name, *args, &block]
        end

        def wedge_plugin(name, *args, &block)
          Wedge.scope!(self)["#{name}_plugin", *args, &block]
        end
      end
      #
      # module RequestClassMethods
      #   def wedge_route_regex
      #     assets_url = ::Wedge.assets_url.gsub(%r{^\/}, '')
      #     # # We also allow for no assets key so when we post server methods there
      #     # # isn't an error if the key has been changed since a browser refresh.
      #     %r{(?:#{assets_url}|#{assets_url.sub("#{::Wedge.config.assets_key}/", '')})/(.*)\.(.*)$}
      #   end
      # end
      #
      # module RequestMethods
      #   def wedge_assets
      #     on self.class.wedge_route_regex do |component, ext|
      #   end
      # end
    end

    register_plugin(:wedge, WedgePlugin)
  end
end
