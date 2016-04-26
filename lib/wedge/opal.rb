class Wedge
  module Plugins
  end

  # Create our own opal instance.
  Opal = ::Opal.dup
  # Opal = Marshal.load(Marshal.dump(::Opal))

  unless RUBY_ENGINE == 'opal'
    module Opal
      class Server
        attr_accessor :headers, :gzip

        def initialize debug_or_options = {}
          unless Hash === debug_or_options
            warn "passing a boolean to control debug is deprecated.\n"+
              "Please pass an Hash instead: Server.new(debug: true)"
            options = {:debug => debug_or_options}
          else
            options = debug_or_options
          end

          @headers     = {}
          @gzip        = false
          @use_index   = true
          @public_root = nil
          @public_urls = ['/']
          @sprockets   = options.fetch(:sprockets, ::Sprockets::Environment.new)
          @debug       = options.fetch(:debug, true)
          @prefix      = options.fetch(:prefix, '/assets')

          Opal.paths.each { |p| @sprockets.append_path(p) }

          yield self if block_given?
          create_app
        end

        def create_app
          server, sprockets, prefix, headers = self, @sprockets, self.prefix, @headers
          sprockets.logger.level ||= Logger::DEBUG
          source_map_enabled = self.source_map_enabled
          if source_map_enabled
            maps_prefix = SOURCE_MAPS_PREFIX_PATH
            maps_app = SourceMapServer.new(sprockets, maps_prefix)
            ::Opal::Sprockets::SourceMapHeaderPatch.inject!(maps_prefix)
          end

          @app = Rack::Builder.app do
            not_found = lambda { |env| [404, {}, []] }
            use Rack::Deflater
            use Rack::ShowExceptions
            use Index, server if server.use_index
            use Headers, server
            if source_map_enabled
              map(maps_prefix) do
                require 'rack/conditionalget'
                require 'rack/etag'
                use Rack::ConditionalGet
                use Rack::ETag
                run maps_app
              end
            end
            map(prefix) { run sprockets }
            run Rack::Static.new(not_found, root: server.public_root, urls: server.public_urls)
          end
        end

        class Headers
          def initialize(app, server)
            @app    = app
            @server = server
          end

          def call(env)
            if env['PATH_INFO'][@server.prefix]
              status, headers, body = @app.call env

              [status, headers.merge(@server.headers), [body]]
            else
              @app.call env
            end
          end
        end
      end
    end
  end


  def self.version
    Wedge::VERSION
  end
end

if RUBY_ENGINE == 'opal'
  class Element
    # alias_native :mask
    alias_native :remove_data, :removeData
    alias_native :replace_with, :replaceWith
    # alias_native :selectize
  end
end

