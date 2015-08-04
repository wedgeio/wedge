unless RUBY_ENGINE == 'opal'
  module Opal
    class Builder
      # @return [String] Compiled javascript.
      def javascript
        to_s
      end
    end

    def self.original_compile(source, options = {})
      Compiler.new(source, options).original_compile
    end

    class Compiler
      alias_method :original_compile, :compile
      def compile
        @result = original_compile

        if defined? Wedge
          logical_path = self.file
          classes    = Wedge.config.component_class
          comp_class = classes["#{Wedge.config.app_dir}/#{logical_path}".gsub(/\//, '__')] || classes[logical_path.gsub(/\//, '__')]

          if logical_path == 'wedge'
            compiled_data = Base64.encode64 Wedge.config.client_data.to_json
            # We need to merge in some data that is only set on the server.
            # i.e. path, assets_key etc....
            @result << Opal.original_compile("require '#{self.file}'; Wedge.config.data = HashObject.new(Wedge.config.data.to_h.merge JSON.parse(Base64.decode64('#{compiled_data}')))")
            # load all global plugins into wedge
            Wedge.config.plugins.each do |path|
              @result << Builder.build(path).to_s
            end
          elsif comp_class
            comp_class.config.on_compile.each { |blk| comp_class.instance_exec(true, &blk) }
            comp_name     = comp_class.config.name
            compiled_data = Base64.encode64 comp_class.config.client_data.to_json
            js            = ''

            js << "require '#{self.file}'; Wedge.config.component_class[:#{comp_name}].config.data = HashObject.new(Wedge.config.component_class[:#{comp_name}].config.data.to_h.merge JSON.parse(Base64.decode64('#{compiled_data}')))"
            # todo: discuss: pass plugin settings that were set server side?
            js << "; Wedge.plugin(:#{comp_name.to_s.gsub(/_plugin$/, '')})" if comp_class.config.is_plugin

            @result << Opal.original_compile(js)

            if compile_str = comp_class.config.compile_str
              @result << compile_str
            end

            load_requires logical_path
          end
        end

        @result
      end

      def load_requires path_name
        if requires = Wedge.config.requires[path_name.gsub(/\//, '__')]
          requires.each do |path|
            next unless comp_class = Wedge.config.component_class[path]

            comp_class.config.on_compile.each { |blk| comp_class.instance_eval(&blk) }

            comp_name     = comp_class.config.name
            compiled_data = Base64.encode64 comp_class.config.client_data.to_json

            load_requires path

            @result << Opal.original_compile("require '#{path}'; Wedge.config.component_class[:#{comp_name}].config.data = HashObject.new(Wedge.config.component_class[:#{comp_name}].config.data.to_h.merge JSON.parse(Base64.decode64('#{compiled_data}')))")
          end
        end
      end
    end

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
          status, headers, body = @app.call env

          headers = {
            'Content-Type' => 'application/javascript; charset=UTF-8'
          }.merge headers

          if env['PATH_INFO'][@server.prefix]
            status, headers, body = @app.call env

            if server.gzip
              require 'zlib'

              headers['Content-Encoding'] = 'gzip'
              body = Zlib::Deflate.deflate body
            end

            [status, headers.merge(@server.headers), [body]]
          else
            @app.call env
          end
        end
      end
    end
  end
end

class Wedge
  # Create our own opal instance.
  Opal = ::Opal.dup

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
else
  # issue: 
  # Wedge::Opal.use_gem 'wedge'
  # NoMethodError:  method `runtime_dependencies' for nil:NilClass
  # /home/rof/cache/bundler/ruby/2.1.0/bundler/gems/opal-921df0c1dcf0/lib/opal/paths.rb:36:in `require_paths_for_gem'
  # /home/rof/cache/bundler/ruby/2.1.0/bundler/gems/opal-921df0c1dcf0/lib/opal/paths.rb:37:in `block in require_paths_for_gem'
  # /home/rof/cache/bundler/ruby/2.1.0/bundler/gems/opal-921df0c1dcf0/lib/opal/paths.rb:36:in `each'
  # /home/rof/cache/bundler/ruby/2.1.0/bundler/gems/opal-921df0c1dcf0/lib/opal/paths.rb:36:in `require_paths_for_gem'
  # /home/rof/cache/bundler/ruby/2.1.0/bundler/gems/opal-921df0c1dcf0/lib/opal/paths.rb:27:in `use_gem'
  # /home/rof/cache/bundler/ruby/2.1.0/gems/wedge-0.1.29/lib/wedge/opal.rb:92:in `<top (required)>'
  # /home/rof/cache/bundler/ruby/2.1.0/gems/wedge-0.1.29/lib/wedge.rb:1:in `require'
  # /home/rof/cache/bundler/ruby/2.1.0/gems/wedge-0.1.29/lib/wedge.rb:1:in `<top (required)>'
  # /home/rof/src/github.com/acdcorp/autolink.cuba/app/config/boot.rb:10:in `require'
  # /home/rof/src/github.com/acdcorp/autolink.cuba/app/config/boot.rb:10:in `<top (required)>'
  # /home/rof/src/github.com/acdcorp/autolink.cuba/Rakefile:15:in `require'
  # /home/rof/src/github.com/acdcorp/autolink.cuba/Rakefile:15:in `<top (required)>'
  # (See full trace by running task with --trace)
  # make: *** [test] Error 1
  Wedge::Opal.append_path Wedge.method(:version).source_location.first.sub('wedge/opal.rb', '')
end

