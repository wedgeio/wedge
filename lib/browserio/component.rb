module BrowserIO
  class Component
    include Methods

    REJECTED_CLIENT_OPTS = %i(scope file_path methods_wrapped events klass on on_server_methods added_class_events loaded html)

    class << self
      # Override the default new behaviour
      def new(*args, &block)
        obj = allocate

        obj.bio_opts.js   = args.delete(:js)
        obj.bio_opts.init = args.delete(:init)

        # Merge other args into opts
        args.each { |a| a.each {|k, v| obj.bio_opts[k] = v } } if args.any?

        obj.bio_opts.events.scope = obj

        # Set all the on events
        obj.bio_opts.on.each do |*a, &b|
          obj.bio_opts.events.add(*a.first.first, &a.first.last)
        end
        bio_opts.added_class_events = true

        if obj.bio_opts.init
          if obj.bio_opts.init.is_a? Array
            obj.send :initialize, *obj.bio_opts.init, &block
          else
            obj.send :initialize, obj.bio_opts.init, &block
          end
        else
          obj.send :initialize, &block
        end

        unless bio_opts.methods_wrapped
          obj.bio_opts.methods_wrapped = bio_opts.methods_wrapped = true

          public_instance_methods(false).each do |meth|
            alias_method :"bio_original_#{meth}", :"#{meth}"
            define_method "#{meth}" do |*d_args, &blk|
              if server? && bio_opts.js
                bio_opts.method_called = meth
                bio_opts.method_args   = *d_args
              end

              o_name = "bio_original_#{meth}"

              if client? || method(o_name).parameters.length > 0
                result = send(o_name, *d_args, &blk)
              else
                result = send(o_name, &blk)
              end

              # Append the initialize javscript
              if server? && opts.js
                result = result.to_html if result.is_a? DOM
                result << bio_javascript if result.is_a? String
              end

              result
            end
          end
        end

        obj
      end

      # Used to setup the component with default options.
      #
      # @example
      #   class SomeComponent < Component
      #     setup do |config|
      #       config.name :some
      #     end
      #   end
      # @yield [Config]
      def bio_setup(&block)
        block.call bio_config
      end
      alias_method :setup, :bio_setup

      # Set templates
      #
      # @example
      #   tmpl :some_name, dom.find('#some-div')
      # @return dom [DOM]
      def bio_tmpl(name, dom = false, remove = true)
        if dom
          dom = remove ? dom.remove : dom
          bio_opts.tmpl[name] = {
            dom:  dom,
            html: dom.to_html
          }
        elsif t = bio_opts.tmpl[name]
          dom = DOM.new t[:html]
        else
          false
        end

        dom
      end
      alias_method :tmpl, :bio_tmpl

      def bio_dom
        @bio_dom ||= DOM.new bio_opts.html
      end
      alias_method :dom, :bio_dom

      # Shortcut for BrowserIO.components
      #
      # @return [Hash, BrowserIO.components]
      def bio_components
        BrowserIO.components ||= {}
      end
      alias_method :components, :bio_components

      # Shortcut for the Config#opts
      #
      # @return [Openstruct, Config#opts]
      def bio_opts
        bio_config.opts
      end
      alias_method :opts, :bio_opts

      def bio_config
        @bio_config ||= begin
          args = BrowserIO.config.opts_dup.merge(klass: self, object_events: {})

          unless RUBY_ENGINE == 'opal'
            args[:file_path] = caller.first.gsub(/(?<=\.rb):.*/, '')
            args[:path_name] = args[:file_path]
              .gsub(%r{(#{Dir.pwd}/|.*(?=browserio))}, '')
              .gsub(/\.rb$/, '')
          end

          c = Config.new(args)

          # If extending from a plugin it will automatically require it.
          ancestors.each do |klass|
            next if klass.to_s == name.to_s

            if klass.method_defined?(:bio_opts) && klass.bio_opts.name.to_s =~ /_plugin$/
              c.requires klass.bio_opts.name
            end
          end

          c
        end
      end
      alias_method :config, :bio_config

      def bio_on(*args, &block)
        if args.first.to_s != 'server'
          bio_opts.on << [args, block]
        else
          bio_on_server(&block)
        end
      end
      alias_method :on, :bio_on

      def method_missing(method, *args, &block)
        if bio_opts.scope.respond_to?(method, true)
          bio_opts.scope.send method, *args, &block
        else
          super
        end
      end

      def client_bio_opts
        bio_config.opts_dup.reject {|k, v| REJECTED_CLIENT_OPTS.include? k }
      end

      def bio_on_server(&block)
        if server?
          yield
        else
          m = Module.new(&block)

          m.public_instance_methods(false).each do |meth|
            bio_opts.on_server_methods << meth.to_s

            define_method "#{meth}" do |*args, &blk|
              path_name = bio_opts.path_name
              # event_id = "comp-event-#{$faye.generate_id}"

              payload = client_bio_opts.reject do |k, _|
                %w(html tmpl requires plugins object_events js_loaded).include? k
              end
              payload[:method_called] = meth
              payload[:method_args]   = args

              HTTP.post("/#{bio_opts.assets_url}/#{path_name}.call",
                headers: {
                  'X-CSRF-TOKEN' => Element.find('meta[name=_csrf]').attr('content')
                },
                payload: payload) do |response|

                  # We set the new csrf token
                  xhr  = Native(response.xhr)
                  csrf = xhr.getResponseHeader('BIO-CSRF-TOKEN')
                  Element.find('meta[name=_csrf]').attr 'content', csrf
                  ###########################

                  res = JSON.from_object(`response`)

                  blk.call res[:body], res
              end

              true
            end
          end

          include m
        end
      end
    end

    # Duplicate of class condig [Config]
    # @return config [Config]
    def bio_config
      @bio_config ||= begin
        c = Config.new(self.class.bio_config.opts_dup.merge(events: Events.new))
        c.opts.events.object_events = c.opts.object_events.dup
        c.opts.object_events = {}
        c
      end
    end
    alias_method :config, :bio_config

    # Duplicated of config.opts [Config#opts]
    # @return opts [Config#opts]
    def bio_opts
      bio_config.opts
    end
    alias_method :opts, :bio_opts

    # Grab a copy of the template
    # @return dom [DOM]
    def bio_tmpl(name)
      self.class.bio_tmpl name
    end
    alias_method :tmpl, :bio_tmpl

    # Dom
    # @return bio_dom [Dom]
    def bio_dom
      @bio_dom ||= begin
        if server?
          DOM.new self.class.bio_dom.to_html
        else
          DOM.new(Element)
        end
      end
    end
    alias_method :dom, :bio_dom

    # Special method that acts like the javascript equivalent
    # @example
    #   foo = {
    #     bar: function { |moo|
    #       moo.call 'something'
    #     }
    #   }.to_n
    def bio_function(*args, &block)
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
    alias_method :function, :bio_function

    def bio_javascript
      return unless server?

      compiled_opts = Base64.encode64 client_bio_opts.to_json
      name          = bio_opts.file_path.gsub("#{Dir.pwd}/", '').gsub(/\.rb$/, '')

      javascript = <<-JS
        BrowserIO.javascript('#{name}', JSON.parse(Base64.decode64('#{compiled_opts}')))
      JS
      "<script>#{Opal.compile(javascript)}</script>"
    end
    alias_method :javscript, :bio_javascript

    def client_bio_opts
      bio_config.opts_dup.reject {|k, v| REJECTED_CLIENT_OPTS.include? k }
    end
    alias_method :client_opts, :client_bio_opts

    def bio_trigger(*args)
      bio_opts.events.trigger(*args)
    end
    alias_method :trigger, :bio_trigger

    if RUBY_ENGINE == 'opal'
      def bio(*args)
        BrowserIO[*args]
      end
    end

    def method_missing(method, *args, &block)
      if bio_opts.scope.respond_to?(method, true)
        bio_opts.scope.send method, *args, &block
      else
        super
      end
    end
  end
end
