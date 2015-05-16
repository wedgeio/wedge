class Roda
  module RodaPlugins
    module Wedge
      def self.configure(app, opts = {})
        if app.opts[:wedge]
          app.opts[:wedge].merge!(opts)
        else
          app.opts[:wedge] = opts.dup
        end

        opts = app.opts[:wedge]

        opts.each do |k, v|
          case k.to_s
          when 'plugins'
            v.each { |p| ::Wedge.config.plugin p }
          when 'scope'
            begin
              ::Wedge.config.scope = v.new
            rescue
              ::Wedge.config.scope = v.new({})
            end
          else
            ::Wedge.config.send "#{k}=", v
          end
        end

        # cache the javascript on load
        Wedge.javascript if opts[:cache_assets]
      end

      module InstanceMethods
        def wedge(name, *args, &block)
          ::Wedge.scope!(self)[name, *args, &block]
        end
      end

      module RequestClassMethods
        def wedge_route_regex
          assets_url = ::Wedge.assets_url.gsub(%r{^\/}, '')
          # # We also allow for no assets key so when we post server methods there
          # # isn't an error if the key has been changed since a browser refresh.
          %r{(?:#{assets_url}|#{assets_url.sub("#{::Wedge.config.assets_key}/", '')})/(.*)\.(.*)$}
        end
      end

      module RequestMethods
        def wedge_assets
          on self.class.wedge_route_regex do |component, ext|
            case ext
            when 'map'
              ::Wedge.source_map component
            when 'rb'
              if component =~ /^wedge/
                path = ::Wedge.config.path.gsub(/\/wedge.rb$/, '')
                File.read("#{path}/#{component}.rb")
              else
                File.read("#{ROOT_PATH}/#{component}.rb")
              end
            when 'call'
              body = scope.request.body.read
              data = scope.request.params

              begin
                data.merge!(body ? JSON.parse(body) : {})
              rescue
                # can't be parsed by json
              end

              data          = data.indifferent
              name          = data.delete(:wedge_name)
              method_called = data.delete(:wedge_method_called)
              method_args   = data.delete(:wedge_method_args)

              if method_args == 'wedge_data' && data
                method_args   = [data]
                res = scope.wedge(name).send(method_called, *method_args) || ''
              else
                res = scope.wedge(name, data).send(method_called, *method_args) || ''
              end

              scope.response.headers["WEDGE-CSRF-TOKEN"] = scope.csrf_token if scope.methods.include? :csrf_token

              if res.is_a? Hash
                scope.response.headers["Content-Type"] = 'application/json; charset=UTF-8'
                res = res.to_json
              else
                res = res.to_s
              end

              res
            else
              scope.response.headers['Content-Type'] = 'application/javascript; charset=UTF-8'

              if ::Wedge.config.debug
                "#{::Wedge.javascript(component)}\n//# sourceMappingURL=/assets/wedge/#{component}.map"
              else
                ::Wedge.javascript(component)
              end
            end
          end
        end
      end
    end

    register_plugin(:wedge, Wedge)
  end
end
