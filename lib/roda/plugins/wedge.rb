class Roda
  module RodaPlugins
    class WedgePlugin
      def self.configure(app, opts = false, &block)
        if !opts || !opts.delete(:disable_middleware)
          app.use Wedge::Middleware, opts || block
        else
          opts.each { |k, v| Wedge.config.send "#{k}=", v }
        end
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

      module RequestMethods
        def wedge_assets
          on Wedge.assets_url_regex do
            run @@__wedge_middleware__ ||= Wedge::Middleware.scope!(scope).new
          end
        end
      end
    end

    register_plugin(:wedge, WedgePlugin)
  end
end
