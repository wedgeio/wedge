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

      # By setting disable_middleware: true and then using r.wedge_assets
      # in your roda routes, wedge components will gain access to the roda scope.
      #
      # warning: this will slow development load times as it re-compiles the js
      # every time.
      module RequestMethods
        def wedge_assets
          on Wedge.assets_url_regex do
            run Wedge::Middleware.scope!(scope)
          end
        end
      end
    end

    register_plugin(:wedge, WedgePlugin)
  end
end
