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
            ::BrowserIO.config.scope v.new('')
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
        alias_method :comp, :bio unless defined? comp
        alias_method :component, :bio unless defined? component
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
