require 'wedge/require'

class Wedge
  class Component
    include Methods

    attr_accessor :wedge_method_called

    class << self
      attr_accessor :wedge_on_count

      def wedge_new(klass, *args, &block)
        obj = allocate

        # discuss: come up with something better
        obj.wedge_method_called = klass.method_called

        %w(store scope).each do |meth|
          if value = klass.send(meth)
            obj.config.send "#{meth}=", value
          end
        end

        unless RUBY_ENGINE == 'opal'
          obj.config.on_compile.each do |blk|
            obj.instance_exec &blk
          end
        end

        if args.length > 0
          obj.config.initialize_args = args
          obj.send :initialize, *args, &block
        else
          obj.send :initialize, &block
        end

        obj
      end

      def plugin *args
        Wedge.plugin *args
      end

      alias_method :original_name, :name
      def wedge_name(*args)
        if args.any?
          unless RUBY_ENGINE == 'opal'
            # set the file path
            path = "#{caller[0]}".gsub(/(?<=\.rb):.*/, '')
              .gsub(%r{(#{Dir.pwd}/#{Wedge.config.app_dir}/|.*(?=wedge))}, '')
              .gsub(/\.rb$/, '')
          end

          @wedge_on_count = 0

          args.each do |name|
            # set the name
            wedge_config.name = name

            unless RUBY_ENGINE == 'opal'
              # set the file path
              wedge_config.path = path
              # add it to the component class list allow path or name
              Wedge.config.component_class[path.gsub(/\//, '__')] = self
            end

            Wedge.config.component_class[name] = self
          end
        else
          original_name
        end
      end
      alias_method :name, :wedge_name

      def wedge_html(html = '', &block)
        unless RUBY_ENGINE == 'opal'
          wedge_config.html = begin
            File.read html
          rescue
            (html.is_a?(HTML::DSL) || html.is_a?(DOM)) ? html.to_html : html
          end.strip

          if block_given?
            yield
          end
        end
      end
      alias_method :html, :wedge_html

      # Set templates
      #
      # @example
      #   tmpl :some_name, dom.find('#some-div')
      # @return dom [DOM]
      def wedge_tmpl(name, dom = false, remove = true)
        if dom
          dom = remove ? dom.remove : dom
          wedge_config.tmpl[name] = {
            dom:  dom,
            html: dom.to_html
          }
        elsif t = wedge_config.tmpl[name]
          dom = DOM.new t[:html]
        else
          false
        end

        dom
      end
      alias_method :tmpl, :wedge_tmpl

      def wedge_dom &block

        unless RUBY_ENGINE == 'opal'
          if block_given?
            yield
          end
        end

        @wedge_dom ||= DOM.new wedge_config.html
      end
      alias_method :dom, :wedge_dom

      def wedge_config
        @wedge_config ||= Config.new klass: self, scope: Wedge.config.scope, plugins: Wedge.config.plugins
      end
      alias_method :config, :wedge_config

      def wedge_on(*args, &block)
        case args.first.to_s
        when 'server'
          wedge_on_server(&block)
        when 'compile'
          wedge_config.on_compile << block unless RUBY_ENGINE == 'opal'
        else
          @wedge_on_count += 1
          Wedge.events.add(config.name, *args, &block)
        end
      end
      alias_method :on, :wedge_on

      def method_missing(method, *args, &block)
        if wedge_config.scope.respond_to?(method, true)
          wedge_config.scope.send method, *args, &block
        else
          puts method
          super
        end
      end

      def wedge_on_server(m = false, &block)
        m ||= Module.new(&block)

        if server?
          yield if block_given?

          m.public_instance_methods(false).each do |meth|
            config.server_methods << meth.to_s

            alias_method :"wedge_on_server_#{meth}", :"#{meth}"
            define_method "#{meth}" do |*args, &blk|
              o_name = "wedge_on_server_#{meth}"

              if method(o_name).parameters.length > 0
                result = send(o_name, *args, &block)
              else
                result = send(o_name, &block)
              end

              blk ? blk.call(result) : result
            end
          end
        else
          m.public_instance_methods(false).each do |meth|
            config.server_methods << meth.to_s

            define_method "#{meth}" do |*args, &blk|
              path_name = config.path

              payload = config.client_data.reject do |k, _|
                %w(html tmpl requires plugins object_events js_loaded).include? k
              end
              payload[:__wedge_name__]   = payload[:name]
              payload[:__wedge_method__] = meth
              payload[:__wedge_args__]   = args

              # we want to remove the assets key from the call so we don't get
              # an error if they assets_key has changed and the user hasn't
              # refreshed the browser yet.
              call_url = "#{Wedge.config.assets_key.present?? Wedge.assets_url.sub("#{Wedge.config.assets_key}/",'') : Wedge.assets_url}/#{path_name}.call"

              if block_given?
                HTTP.post(call_url,
                  headers: {
                    'X-CSRF-TOKEN' => Element.find('meta[name=_csrf]').attr('content'),
                    'X-WEDGE-METHOD-REQUEST' => meth
                  },
                  payload: payload) do |response|

                    # We set the new csrf token
                    xhr  = Native(response.xhr)
                    # discuss: I don't think we should update the csrf token every ajax call
                    # csrf = xhr.getResponseHeader('WEDGE-CSRF-TOKEN')
                    # Element.find('meta[name=_csrf]').attr 'content', csrf
                    ###########################

                    res = JSON.from_object(`response`)

                    blk.call res[:body], res
                end
              else
                data = {
                  headers: {
                   'X-CSRF-TOKEN' => "#{Element.find('meta[name=_csrf]').attr('content')}",
                   'X-WEDGE-METHOD-REQUEST' => meth
                  },
                  dataType: 'json',
                  type: 'POST',
                  url: call_url,
                  data: payload,
                  async: false
                }.to_n

                response = `$.ajax(data).responseText`
                begin
                  JSON.parse response
                rescue
                  if response.empty?
                    raise "Ajax response to #{call_url} was empty."
                  else
                    puts response
                  end
                end
              end
            end
          end

          include m
        end
      end

      def set_dom dom
        @wedge_dom = dom.is_a?(Wedge::DOM) ? dom : Wedge::DOM.new(dom)
      end

      def html!(&b)
        Wedge.html!(self, &b)
      end

      def store
        wedge_config.store
      end
    end

    # We want the scope to override this method if defined
    def wedge(*args, &block)
      # fix: can't pass block to Wedge, opal error:
      # https://github.com/opal/opal/issues/959
      # scope.respond_to?(:wedge) ? scope.wedge(*args, &block) : Wedge[*args, &block]
      scope.respond_to?(:wedge) ? scope.wedge(*args, &block) : Wedge[*args]
    end

    # We want the scope to override this method if defined
    def wedge_plugin(name, *args, &block)
      scope.respond_to?(:wedge_plugin) ? scope.wedge_plugin(*args, &block) : wedge("#{name}_plugin", *args, &block)
    end

    def wedge_scope
      wedge_config.scope
    end
    alias_method :scope, :wedge_scope

    def wedge_store
      wedge_config.store
    end
    alias_method :store, :wedge_store

    def wedge_class_store
      self.class.wedge_config.store
    end
    alias_method :class_store, :wedge_class_store

    # Duplicate of class condig [Config]
    # @return config [Config]
    def wedge_config
      @wedge_config ||= Config.new(self.class.wedge_config.data.deep_dup)
    end
    alias_method :config, :wedge_config

    # Grab a copy of the template
    # @return dom [DOM]
    def wedge_tmpl(name)
      self.class.wedge_tmpl name
    end
    alias_method :tmpl, :wedge_tmpl

    # Dom
    # @return wedge_dom [Dom]
    def wedge_dom
      @wedge_dom ||= begin
        if server?
          DOM.new self.class.wedge_dom.to_html
        else
          DOM.new(Element)
        end
      end
    end
    alias_method :dom, :wedge_dom

    # Special method that acts like the javascript equivalent
    # @example
    #   foo = {
    #     bar: function { |moo|
    #       moo.call 'something'
    #     }
    #   }.to_n
    def wedge_function(*args, &block)
      args.any? && raise(ArgumentError, '`function` does not accept arguments')
      block || raise(ArgumentError, 'block required')
      proc do |*a|
        a.map! {|x| Native(`x`)}
        @this = Native(`this`)
        %x{
         var bs = block.$$s,
            result;
          block.$$s = null;
          result = block.apply(self, a);
          block.$$s = bs;

          return result;
        }
      end
    end
    alias_method :function, :wedge_function

    def wedge_method_url method, *args
      call_url = "#{Wedge.config.assets_key.present?? Wedge.assets_url.sub("#{Wedge.config.assets_key}/",'') : Wedge.assets_url}/#{wedge_config.path}.call"

      wedge_args = []
      args.each do |arg|
        wedge_args << "__wedge_args__[]=#{arg}"
      end

      wedge_args = (wedge_args.length > 0 ? "&#{wedge_args.join('&')}" : '')

      "#{call_url}?__wedge_name__=#{wedge_config.name}&__wedge_method__=#{method}#{wedge_args}"
    end
    alias_method :method_url, :wedge_method_url

    def wedge_from_server?
      begin
        !(wedge_method_called == caller_locations(1,1)[0].label)
      rescue
        true
      end
    end
    alias_method :from_server?, :wedge_from_server?

    alias_method :method_called, :wedge_method_called

    def wedge_from_client?
      begin
        wedge_method_called == caller_locations(1,1)[0].label
      rescue
        false
      end
    end
    alias_method :from_client?, :wedge_from_client?

    def wedge_javascript(method = false, *args)
      return unless server?

      client_data = config.client_data.dup
      client_data.merge!(
        method_called: method,
        method_args: args,
        initialize_args: config.initialize_args
      )

      compiled_opts = Base64.encode64 client_data.to_json
      javascript = <<-JS
        Wedge.javascript('#{config.path}', JSON.parse(Base64.decode64('#{compiled_opts}')))
      JS
      "<script>#{Opal.compile(javascript)}</script>"
    end
    alias_method :javscript, :wedge_javascript

    def wedge_trigger(event_name, *args)
      Wedge.events.trigger config.name, event_name, *args
    end
    alias_method :trigger, :wedge_trigger

    def to_js(method = false, *args)
      response = args.any? ? send(method, *args) : send(method)
      response = response.to_html if response.is_a? DOM
      response << wedge_javascript(method, *args) if response.is_a? String
      response
    end

    def wedge_html(&b)
      Wedge.html!(self, &b)
    end
    alias_method :html!, :wedge_html

    def method_missing(method, *args, &block)
      if config.scope.respond_to?(method, true)
        config.scope.send method, *args, &block
      else
        super
      end
    end
  end
end
