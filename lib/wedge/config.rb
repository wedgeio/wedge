require 'ostruct'
require 'wedge/events'

module Wedge
  class Config
    include Methods

    # Stores the options for the config
    #
    # @return [OpenStruct]
    attr_accessor :opts

    # Setup initial opts values
    #
    # @param opts [Hash] The initial params for #opts.
    def initialize(opts = {})
      opts = {
        cache_assets: false,
        cache: IndifferentHash.new,
        assets_key: false,
        tmpl: IndifferentHash.new,
        scope: false,
        loaded: false,
        requires: [],
        on: [],
        on_server_methods: [],
        object_events: {},
        is_plugin: false,
        assets_url: '/assets/wedge',
        plugins: []
      }.merge opts

      @opts = OpenStruct.new(opts)
    end

    # Set the unique name of the component
    #
    # @param name [<String, Symbol>, #to_sym]
    def name(*names)
      names.each do |name|
        opts.name = name.to_sym
        opts.is_plugin = true if name.to_s =~ /_plugin$/
        Wedge.components ||= {}
        Wedge.components[opts.name] = opts
      end
    end

    def is_plugin?
      opts.is_plugin
    end

    # Used to set and update the dom
    def dom
      if server?
        yield
      end
    end
    alias_method :setup, :dom

    # Set the raw html
    # @param html [String]
    def html(html)
      unless RUBY_ENGINE == 'opal'
        opts.html = begin
          File.read html
        rescue
          html
        end.strip
      end
    end

    def requires(*args)
      unless RUBY_ENGINE == 'opal'
        args.each do |a|
          if a.to_s[/_plugin$/]
            require "wedge/plugins/#{a.to_s.gsub(/_plugin$/, '')}"
          end
          opts.requires << a
        end
      end
    end

    def opts_dup
      opts.to_h.inject({}) {|copy, (key, value)| copy[key] = value.dup rescue value; copy}
    end

    %w(scope assets_url cache_assets assets_key debug).each do |m|
      define_method m do |v|
        opts[m] = v
      end
    end

    def plugin(name)
      unless RUBY_ENGINE == 'opal'
        require "wedge/plugins/#{name}"
        klass = Wedge.components[:"#{name}_plugin"].klass
        Wedge::Component.include(klass::InstanceMethods) if defined?(klass::InstanceMethods)
        Wedge::Component.extend(klass::ClassMethods) if defined?(klass::ClassMethods)
      end
    end

    def get_requires(requires = false, previous_requires = [])
      list = []

      unless requires
        requires ||= opts.requires.dup
        previous_requires << opts.name.to_sym
      end

      previous_requires.each { |p| requires.delete(p) }

      requires.each do |r|
        begin
          klass = Wedge.components[r.to_sym].klass
        rescue
          raise "No component named: #{r}"
        end
        o = klass.client_wedge_opts.select do |k, v|
          %w(path_name name requires).include? k.to_s
        end

        # We don't want to get a stack limit error so we stop something
        # requiring itself
        pr = previous_requires.dup << o[:name].to_sym

        o[:requires] = get_requires o[:requires].dup, pr if o[:requires].present?

        list << o
      end

      list
    end
  end
end
