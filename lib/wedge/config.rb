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
        cache_assets: false,
        is_plugin: false,
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
        allowed_client_data: %w(name path method_args method_called store tmpl key cache_assets assets_key assets_url assets_url_with_host)
      }.merge(opts))
    end

    def client_data
      @data.dup.select {|k, v| allowed_client_data.include? k }
    end

    def plugin(name, settings = {}, &block)
      unless RUBY_ENGINE == 'opal'
        require "wedge/plugins/#{name}"
      end

      klass = Wedge.config.component_class[:"#{name}_plugin"]

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

    def method_missing(method, *args, &block)
      if @data.respond_to?(method, true)
        @data.send method, *args, &block
      else
        super
      end
    end
  end
end
