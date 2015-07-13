class Wedge
  class Config
    include Methods

    # Stores the options for the config
    #
    # @return [OpenStruct]
    attr_accessor :data

    # Setup initial opts values
    #
    # @param opts [Hash] The initial params for #opts.
    def initialize(opts = {})
      @data = HashObject.new({
        name: nil,
        path: nil,
        html: nil,
        scope: nil,
        block: nil,
        debug: false,
        app_dir: 'app',
        assets_url: '/assets/wedge',
        assets_key: nil,
        assets_headers: {},
        cache_assets: false,
        is_plugin: false,
        compile_str: false,
        skip_call_middleware: false,
        requires: IndifferentHash.new,
        triggered_browser_events: false,
        store: IndifferentHash.new,
        settings: IndifferentHash.new,
        tmpl: IndifferentHash.new,
        on_block: [],
        on_compile: [],
        on_block_count: 0,
        server_methods: [],
        initialize_args: [],
        plugins: [],
        opal: {},
        allowed_client_data: %w(debug name path method_args method_called store tmpl key cache_assets assets_key assets_url assets_url_with_host)
      }.merge(opts))
    end

    def client_data
      @data.dup.select {|k, v| allowed_client_data.include? k }
    end

    def plugin(name, settings = {}, &block)
      plugin_name = "#{name}_plugin"

      Wedge.config.settings[plugin_name] = settings

      unless RUBY_ENGINE == 'opal'
        require "wedge/plugins/#{name}"
      end

      klass = Wedge.config.component_class[plugin_name]

      unless plugins.include? klass.config.path
        klass.config.settings  = settings
        klass.config.block     = block
        klass.config.is_plugin = true

        plugins << klass.config.path
        plugins.uniq!

        # Merge in instance/class methods
        Wedge::Component.send(:include, klass::InstanceMethods) if defined?(klass::InstanceMethods)
        Wedge::Component.extend(klass::ClassMethods) if defined?(klass::ClassMethods)
      end
    end

    def plugins= plugins
      plugins.each { |p| plugin(p.to_s) }
    end

    def scope= value
      if value.respond_to? :new
        begin
          @data.scope = value.new
        rescue
          @data.scope = value.new({})
        end
      else
        @data.scope = value
      end
    end

    def method_missing(method, *args, &block)
      if @data.respond_to?(method, true)
        @data.send method, *args, &block
      else
        super
      end
    end
  end
end
