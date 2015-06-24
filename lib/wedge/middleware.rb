class Wedge
  class Middleware
    def initialize(app, settings = {})
      @app  = app
      @opal = Wedge::Opal::Server.new { |s|
        s.prefix = Wedge.config.assets_url
        s.append_path "#{Dir.pwd}/#{Wedge.config.app_dir}"
        s.debug = Wedge.config.debug
      }

      settings.each do |k, v|
        Wedge.config.send "#{k}=", v
      end
    end

    def call(env)
      responder = Responder.new(@app, @opal, env)
      responder.respond
    end

    class Responder
      attr_reader :opal
      attr_accessor :app, :env, :wedge_path, :extension

      def initialize(app, opal, env)
        @app = app; @opal = opal; @env = env
      end

      def respond
        if path =~ Wedge.assets_url_regex
          @wedge_path, @extension = $1, $2
          body, headers, status = [], {}, 200

          if extension == 'call'
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

            if method_args == '__wedge_data__' && data
              method_args = [data]
              res         = Wedge.scope!(self)[name].send(method_called, *method_args) || ''
            else
              # This used to send things like init, we need a better way to
              # send client config data to the server
              # res = scope.wedge(name, data).send(method_called, *method_args) || ''
              res = Wedge.scope!(self)[name].send(method_called, *method_args) || ''
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
            @opal.call env
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
        @env['PATH_INFO']
      end

      def request
        @request ||= Rack::Request.new(@env)
      end

      def response
        @response ||= begin
          status, headers, body = @app.call(request.env)
          Rack::Response.new(body, status, headers)
        end
      end
    end
  end
end
