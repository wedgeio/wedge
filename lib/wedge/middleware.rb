class Wedge
  class Middleware
    def initialize(app, settings = {})
      @app = app

      # Add settings to wedge
      settings.each do |k, v|
        Wedge.config.send "#{k}=", v
      end
    end

    def call(env)
      responder = Responder.new(@app, env)
      responder.respond
    end

    class Responder
      attr_accessor :app, :env, :wedge_path, :extension

      def initialize(app, env)
        @app = app; @env = env
      end

      def respond
        if path =~ Wedge.assets_url_regex
          @wedge_path, @extension = $1, $2
          body, headers, status = [], {}, 200

          case extension
          when 'map'
            ::Wedge.source_map wedge_path
          when 'rb'
            if wedge_path =~ /^wedge/
              path = ::Wedge.config.path.gsub(/\/wedge.rb$/, '')
              File.read("#{path}/#{wedge_path}.rb")
            else
              File.read("#{ROOT_PATH}/#{wedge_path}.rb")
            end if Wedge.config.debug
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
              res = Wedge.scope!(app)[name].send(method_called, *method_args) || ''
            else
              res = Wedge.scope!(app)[name, data].send(method_called, *method_args) || ''
            end

            headers["WEDGE-CSRF-TOKEN"] = scope.csrf_token if scope.methods.include? :csrf_token

            if res.is_a? Hash
              headers["Content-Type"] = 'application/json; charset=UTF-8'
              body = res.to_json
            else
              body = res.to_s
            end
          else
            headers['Content-Type'] = 'application/javascript; charset=UTF-8'

            if Wedge.config.debug
              body << "#{Wedge.javascript(wedge_path)}\n//# sourceMappingURL=#{Wedge.assets_url}/#{wedge_path}.map"
            else
              binding.pry
              body << Wedge.javascript(wedge_path)
            end
          end

          [status, headers, body.join]
        else
          response.finish
        end
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
