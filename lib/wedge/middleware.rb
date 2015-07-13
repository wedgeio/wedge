class Wedge
  class Middleware
    attr_reader :skip_call

    def initialize(app = false, settings = false)
      if settings
        case settings
        when Proc
          Wedge.config.instance_eval &settings
        else
          settings.each { |k, v| Wedge.config.send "#{k}=", v }
        end

        Wedge.config.opal = { server: Wedge::Opal::Server.new { |s|
          s.prefix = Wedge.assets_url
          s.debug  = Wedge.config.debug
          s.append_path "#{Dir.pwd}/#{Wedge.config.app_dir}"
        }}

        if Wedge.config.debug
          Wedge.config.opal[:sprockets]   = Wedge.config.opal[:server].sprockets
          Wedge.config.opal[:maps_prefix] = "#{Wedge.assets_url}/__OPAL_SOURCE_MAPS__"
          Wedge.config.opal[:maps_app]    = Opal::SourceMapServer.new Wedge.config.opal[:sprockets], Wedge.config.opal[:maps_prefix]

          Wedge::Opal::Sprockets::SourceMapHeaderPatch.inject! Wedge.config.opal[:maps_prefix]
        end
      end

      @app       = app
      @scope     = self.class.scope
      @skip_call = !self.class.skip_call.nil?? self.class.skip_call : Wedge.config.skip_call_middleware
      @opal      = Wedge.config.opal
    end

    def call(env)
      responder = Responder.new(@app, @opal, @scope, @skip_call, env)
      responder.respond
    end

    class << self
      attr_accessor :scope, :skip_call

      def scope! scope
        klass = Class.new(self)
        klass.instance_variable_set(:@scope, scope)
        klass.instance_variable_set(:@skip_call, false)
        klass
      end

      def call env
        self.new.call env
      end
    end

    class Responder
      attr_reader :opal, :scope, :skip_call
      attr_accessor :app, :env, :wedge_path, :extension

      def initialize(app, opal, scope, skip_call, env)
        @app = app; @opal = opal; @scope = (scope || self); @skip_call = skip_call; @env = env
      end

      def respond
        if path =~ Wedge.assets_url_regex
          @wedge_path, @extension = $1, $2

          if extension == 'call'
            return response.finish if skip_call

            body, headers, status = [], {}, 200

            body_data = request.body.read
            data      = request.params

            begin
              # try json
              data.merge!(body_data ? JSON.parse(body_data) : {})
            rescue
              begin
                # try form data
                data.merge!(body_data ? Rack::Utils.parse_query(body_data) : {})
              rescue
                # no data
              end
            end

            data          = data.indifferent
            name          = data.delete(:__wedge_name__)
            method_called = data.delete(:__wedge_method__)
            method_args   = data.delete(:__wedge_args__)


            if wedge_path == 'wedge/list_assets'
              res = {
                urls: Wedge.get_asset_urls(data[:path_name]),
                code: Wedge::Opal::Processor.load_asset_code(Wedge.config.opal[:server].sprockets, data[:path_name])
              }
            elsif method_args == '__wedge_data__' && data
              method_args = [data]
              res         = Wedge.scope!(scope, method_called)[name].send(method_called, *method_args) || ''
            else
              # This used to send things like init, we need a better way to
              # send client config data to the server
              # res = scope.wedge(name, data).send(method_called, *method_args) || ''
              res = Wedge.scope!(scope, method_called)[name].send(method_called, *method_args) || ''
            end

            # discuss: I don't think we should update the csrf token # every ajax call
            # headers["WEDGE-CSRF-TOKEN"] = self.csrf_token if self.methods.include? :csrf_token

            if res.is_a? Hash
              headers["Content-Type"] = 'application/json; charset=UTF-8'
              body << res.to_json
            else
              body << res.to_s
            end

            [status, headers, body]
          else
            if Wedge.config.debug
              if path[@opal[:maps_prefix]]
                @opal[:maps_app].call env
              else
                e = env.deep_dup
                e['PATH_INFO'] = env['PATH_INFO'].sub "#{Wedge.assets_url_with_host}/", ''
                @opal[:sprockets].call e
              end
            else
              @opal[:server].call env
            end
          end
        else
          response.finish
        end
      end

      def wedge(*args, &block)
        Wedge[*args, &block]
      end

      private

      def path
        @env['PATH_INFO'].present?? @env['PATH_INFO'] : @env['PATH_INFO'] = @env['REQUEST_PATH']
      end

      def request
        @request ||= Rack::Request.new(@env)
      end

      def response
        @response ||= begin
          status, headers, body = (@app ? @app.call(request.env) : [404, {}, ''])
          Rack::Response.new(body, status, headers)
        end
      end
    end
  end
end
