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
        debug: false,
        assets_url: '/assets/wedge',
        assets_key: false,
        cache_assets: false,
        is_plugin: false,
        requires: IndifferentHash.new,
        triggered_browser_events: false,
        store: IndifferentHash.new,
        settings: IndifferentHash.new,
        tmpl: IndifferentHash.new,
        on_block: [],
        on_block_count: 0,
        server_methods: [],
        initialize_args: [],
        before_compile: [],
        plugins: [],
        allowed_client_data: %w(name path method_args method_called store tmpl key cache_assets assets_key assets_url assets_url_with_host)
      }.merge(opts))
    end

    def client_data
      @data.dup.select {|k, v| allowed_client_data.include? k }
    end

    def plugin(name)
      unless RUBY_ENGINE == 'opal'
        require "wedge/plugins/#{name}"
      end

      klass = Wedge.config.component_class[:"#{name}_plugin"]
      plugins << klass.config.path unless plugins.include? klass.config.path

      # Merge in instance/class methods
      Wedge::Component.include(klass::InstanceMethods) if defined?(klass::InstanceMethods)
      Wedge::Component.extend(klass::ClassMethods) if defined?(klass::ClassMethods)
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
