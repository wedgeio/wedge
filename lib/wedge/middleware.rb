class Wedge
  class Middleware
    attr_reader :skip_call

    def initialize(app = false, settings = false)
      Wedge.load_settings settings

      @app       = app
      @scope     = self.class.scope
      @skip_call = !self.class.skip_call.nil?? self.class.skip_call : Wedge.config.skip_call_middleware
      @opal      = Wedge.config.opal
    end

    def call(env)
      responder = Responder.new(@app, @opal, @scope, @skip_call, env)
      responder.respond
    ensure
      Wedge::Store.clear!
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
            # no clue why you need to do __wedge_args__[]
            method_args   = data.delete(:__wedge_args__) || data.delete(:'__wedge_args__[]')

            if wedge_path == 'wedge/list_assets'
              res = {
                urls: Wedge.get_asset_urls(data[:path_name]),
                code: Wedge::Opal::Sprockets.load_asset(data[:path_name], Wedge.config.opal[:server].sprockets)
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
              status, headers, body = @opal[:server].call env

              headers['Content-Type'] = 'application/javascript; charset=UTF-8'

              if Wedge.config.gzip_assets
                require 'zlib'

                headers['Content-Encoding'] = 'gzip'
                headers.delete 'Content-Length'

                wio = StringIO.new("")
                w_gz = Zlib::GzipWriter.new(wio)
                w_gz.write((body.instance_variable_get(:@body) || body).last.to_s)
                w_gz.close

                body = wio.string
              end

              [status, headers, [body]]
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
