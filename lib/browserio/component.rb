module BrowserIO
  class Component
    class << self
      # Override the default new behaviour
      def new(*args, &block)
        obj                 = allocate
        obj.opts.render_js  = args.delete(:render_js)
        obj.opts.initialize = args.delete(:init) || args.delete(:initialize)

        if obj.method(:initialize).parameters.length > 0
          obj.send :initialize, obj.opts.initialize, &block
        else
          obj.send :initialize, &block
        end

        unless opts[:methods_wrapped]
          opts[:methods_wrapped] = true

          public_instance_methods(false).each do |meth|
            alias_method :"bio_original_#{meth}", :"#{meth}"
            define_method "#{meth}" do |*d_args|
              o_name = "bio_original_#{meth}"

              if method(o_name).parameters.length > 0
                result = send(o_name, *d_args, &block)
              else
                result = send(o_name, &block)
              end

              result
            end
          end
        end

        obj
      end

      # Set templates
      #
      # @example
      #   tmpl :some_name, dom.find('#some-div')
      # @return dom [DOM]
      def bio_tmpl(name, dom = false, remove = false)
        if dom
          dom = remove ? dom.remove : dom
          opts.tmpl[name] = {
            dom:  dom,
            html: dom.to_html
          }
        elsif t = opts.tmpl[name]
          dom = DOM.new t[:html]
        else
          false
        end

        dom
      end
      alias_method :tmpl, :bio_tmpl

      def bio_dom
        @bio_dom ||= DOM.new opts.html
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
        config.opts
      end
      alias_method :opts, :bio_opts

      def bio_config
        @bio_config ||= Config.new(klass: self, file: caller.first.gsub(/(?<=\.rb):.*/, ''))
      end
      alias_method :config, :bio_config
      alias_method :setup,  :bio_config
    end

    # Duplicate of class condig [Config]
    # @return config [Config]
    def bio_config
      @bio_config ||= self.class.bio_config.dup
    end
    alias_method :config, :bio_config

    # Duplicated of config.opts [Config#opts]
    # @return opts [Config#opts]
    def bio_opts
      @bio_opts ||= bio_config.opts.dup
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
      @bio_dom ||= DOM.new self.class.bio_dom.to_html
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
  end
end
