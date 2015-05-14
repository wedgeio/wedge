module Wedge
  class Config
    include Methods

    ALLOWED_CLIENT_OPTS = %i(name path_name method_args method_called cache tmpl key cache_assets assets_key assets_url assets_url_with_host requires skip_method_wrap on_server_methods)

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
        assets_url: '/assets/wedge',
        assets_key: false,
        cache_assets: false,
        is_plugin: false,
        store: IndifferentHash.new,
        tmpl: IndifferentHash.new,
        on_block: [],
        server_method: [],
      }.merge(opts))
    end

    def client_data
      @data.dup.select {|k, v| ALLOWED_CLIENT_OPTS.include? k }
    end

    def plugin(name)
      unless RUBY_ENGINE == 'opal'
        require "wedge/plugins/#{name}"
      end

      klass = Wedge.config.component_class[:"#{name}_plugin"]
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
