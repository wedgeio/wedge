module BrowserIO
  class Component
    include Methods

    REJECTED_CLIENT_OPTS = %i(scope file_path methods_wrapped events)

    class << self
      alias_method :__new__, :new

      # Override the default new behaviour
      def new(*args, &block)
        obj = allocate

        obj.bio_opts.js   = args.delete(:js)
        obj.bio_opts.init = args.delete(:init)

        # Merge other args into opts
        args.each { |a| a.each {|k, v| obj.bio_opts[k] = v } } if client?

        if obj.bio_opts.init && obj.method(:initialize).parameters.length > 0
          obj.send :initialize, obj.bio_opts.init, &block
        else
          obj.send :initialize, &block
        end

        obj.bio_opts.events.scope = obj

        unless bio_opts.methods_wrapped
          obj.bio_opts.methods_wrapped = bio_opts.methods_wrapped = true

          public_instance_methods(false).each do |meth|
            alias_method :"bio_original_#{meth}", :"#{meth}"
            define_method "#{meth}" do |*d_args|
              if bio_opts.js
                bio_opts.method_called = meth
                bio_opts.method_args   = *d_args
              end

              o_name = "bio_original_#{meth}"

              if client? || method(o_name).parameters.length > 0
                result = send(o_name, *d_args, &block)
              else
                result = send(o_name, &block)
              end

              # Append the initialize javscript
              if server? && opts.js
                result = result.to_html if result.is_a? DOM
                result << bio_javascript
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
      def bio_tmpl(name, dom = false, remove = false)
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
          args = BrowserIO.opts.to_h.merge(klass: self)

          if RUBY_ENGINE == 'ruby'
            args[:file_path] = caller.first.gsub(/(?<=\.rb):.*/, '')
          end

          Config.new(args)
        end
      end
      alias_method :config, :bio_config

      def on(*args, &block)
        bio_opts.events.add *args, &block
      end

      def method_missing(method, *args, &block)
        if server? && bio_opts.scope.respond_to?(method, true)
          bio_opts.scope.send method, *args, &block
        else
          super
        end
      end
    end

    # Duplicate of class condig [Config]
    # @return config [Config]
    def bio_config
      @bio_config ||= Config.new(self.class.bio_config.opts.to_h)
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

      compiled_opts = Base64.encode64 bio_opts.to_h.reject {|k, v| REJECTED_CLIENT_OPTS.include? k }.to_json
      name          = bio_opts.file_path.gsub("#{Dir.pwd}/", '').gsub(/\.rb$/, '')

      javascript = <<-JS
        BrowserIO.javascript('#{name}', JSON.parse(Base64.decode64('#{compiled_opts}')))
      JS
      "<script>#{Opal.compile(javascript)}</script>"
    end
    alias_method :javscript, :bio_javascript

    def bio_trigger *args
      bio_opts.events.trigger *args
    end
    alias_method :trigger, :bio_trigger

    def method_missing(method, *args, &block)
      if server? && bio_opts.scope.respond_to?(method, true)
        bio_opts.scope.send method, *args, &block
      else
        super
      end
    end
  end
end
