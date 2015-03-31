class Roda
  module RodaPlugins
    module BrowserIO
      def self.configure(app, opts = {})
        if app.opts[:browserio]
          app.opts[:browserio].merge!(opts)
        else
          app.opts[:browserio] = opts.dup
        end

        opts = app.opts[:browserio]

        opts.each do |k, v|
          case k.to_s
          when 'plugins'
            v.each { |p| ::BrowserIO.config.plugin p }
          when 'scope'
            begin
              ::BrowserIO.config.scope v.new
            rescue
              ::BrowserIO.config.scope v.new('')
            end
          else
            ::BrowserIO.config.send(k, v)
          end
        end
      end

      module InstanceMethods
        def bio(*args)
          args << { scope: self }
          ::BrowserIO[*args]
        end
      end

      module RequestClassMethods
        def bio_route_regex
          %r{#{roda_class.opts[:browserio][:assets_url]}/(.*)\.(.*)$}
        end
      end

      module RequestMethods
        def browserio
          on self.class.bio_route_regex do |component, ext|
            case ext
            when 'map'
              ::BrowserIO.source_map component
            when 'rb'
              if component =~ /^browserio/
                path = ::BrowserIO.opts.file_path.gsub(/\/browserio.rb$/, '')
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
              name          = data.delete(:name)
              method_called = data.delete(:method_called)
              method_args   = data.delete(:method_args)

              res = scope.bio(name, data).send(method_called, *method_args) || ''

              scope.response.headers["BIO-CSRF-TOKEN"] = scope.csrf_token if scope.methods.include? :csrf_token

              if res.is_a? Hash
                scope.response.headers["Content-Type"] = 'application/json; charset=UTF-8'
                res = res.to_json
              else
                res = res.to_s
              end

              res
            else
              "#{::BrowserIO.javascript(component)}\n//# sourceMappingURL=/assets/bio/#{component}.map"
            end
          end
        end
      end
    end

    register_plugin(:browserio, BrowserIO)
  end
end
