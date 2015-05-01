require 'wedge/opal'
require 'wedge/version'
require 'wedge/utilis/indifferent_hash'
require 'wedge/utilis/hash'
require 'wedge/utilis/blank'
require 'wedge/utilis/methods'
require 'wedge/utilis/try'
require 'wedge/utilis/titleize'
require 'wedge/utilis/element'
require 'base64'
unless RUBY_ENGINE == 'opal'
  require 'nokogiri'
  require 'wedge/utilis/nokogiri'
end
require 'wedge/html'
require 'wedge/dom'
require 'wedge/config'
require 'wedge/component'

module Wedge
  include Methods

  class << self
    attr_accessor :requires, :loaded_requires, :loaded_requires_events, :javascript_cache,
      :wedge_javascript_loaded, :object_events, :browser_events

    def compile_opal
      javascript
    end

    def assets_url
      "#{opts.assets_url}#{opts.cache_assets ? "/#{opts.assets_key}" : ''}"
    end

    def script_tag
      "<script src='#{assets_url}/wedge.js'></script>"
    end

    # Used to call a component.
    #
    # @example
    #   Browser[:foo].bar
    #
    # @param name [String, Symbol, #to_s] The unique name given to a component.
    # @return [Wedge::Component#method] Last line of the method called.
    def [](name, *args)
      component = components[name.to_sym]

      component.klass.new(*args)
    end

    def components
      @components ||= OpenStruct.new
    end

    unless RUBY_ENGINE == 'opal'
      # Returns the build object for opal.
      #
      # @param path [String] require path to file to build.
      # @return [String, Opal::Builder#build]
      def build(path = 'wedge', options = {})
        append_paths
        Opal::Builder.build(path, options)
      end

      # Source maps for the javascript
      def source_map(path = 'wedge', options = {})
        build(path, options).source_map
      end

      # Append the correct paths to opal.
      #
      # @return [Array] List of opal paths.
      def append_paths
        @append_paths ||= begin
          file = method(:components).source_location.first.sub('/wedge.rb', '')
          Wedge::Opal.append_path file
          Wedge::Opal.append_path Dir.pwd
        end
      end
    end

    # Return the opal javascript.
    def javascript(path_name = 'wedge', options = {}, promise = false)
      if server?
        if path_name == 'wedge'
          @wedge_javascript ||= begin
            @wedge_javascript_loaded = true
            requires      = {}
            @object_events = {}
            @browser_events = {}

            @javascript_cache ||= {}

            components.to_h.each do |k, v|
              requires[k]      = v.klass.wedge_config.get_requires
              # events = Wedge[v.name].wedge_opts.events
              # @object_events[v.name]  = events.object_events
              # @browser_events[v.name] = events.browser_events
              javascript(v.klass.wedge_opts[:path_name])
            end

            compiled_requires = Base64.encode64 requires.to_json
            # compiled_object_events = Base64.encode64 object_events.to_json
            assets_key        = opts.assets_key
            cache_assets      = opts.cache_assets

            js = build(path_name, options).javascript
            js << Opal.compile("Wedge.instance_variable_set(:@requires, JSON.parse(Base64.decode64('#{compiled_requires}')))")
            # fix: we need to just merge in all config opts and just reject
            # certain ones
            js << Opal.compile("Wedge.config.assets_key('#{assets_key}')") if assets_key
            js << Opal.compile("Wedge.config.cache_assets('#{cache_assets}')") if cache_assets
            js << Opal.compile("Wedge.config.assets_url('#{opts.assets_url}')")
            ##############################################################
            js
          end
        else
          @javascript_cache[path_name] ||= begin
            js = build(path_name, options).javascript
            comp_name = components.to_h.select { |k, v| v.path_name == path_name }.first.last.name
            comp = Wedge[comp_name]
            options = comp.client_wedge_opts
            compiled_opts = Base64.encode64 options.to_json
            js << Opal.compile("Wedge.components[:#{comp_name}].klass.instance_variable_set(:@wedge_config, Wedge::Config.new(Wedge.components[:#{comp_name}].klass.wedge_config.opts_dup.merge(JSON.parse(Base64.decode64('#{compiled_opts}')))))")
          end
        end
      else
        Wedge.loaded_requires ||= []
        Wedge.loaded_requires_events ||= []
        reqs     = Wedge.requires[options[:name].to_sym]
        promise  = Promise.new

        if reqs
          requires = get_requires(reqs.dup)
          load_requires(requires.dup, promise)
        else
          promise.resolve true
        end

        promise.then do
          load_comp(options).then do
            method_called = options[:method_called]
            method_args   = options[:method_args]
            name          = options[:name]
            comp          = Wedge[name, options]

            Document.ready? do
              trigger_requires_events requires.dup
              comp.send(method_called, *method_args) if method_called
              comp.wedge_trigger :browser_events
            end
          end
        end
      end
    end

    def trigger_requires_events requires
      reqs = requires.shift

      reqs.each do |r|
        next if Wedge.loaded_requires_events.include? r[:name]
        Wedge.loaded_requires_events << r[:name]
        comp = Wedge[r[:name], r]
        comp.wedge_trigger :browser_events
      end

      trigger_requires_events requires if requires.any?
    end

    def load_requires requires, promise = Promise.new
      reqs     = requires.shift
      promises = []

      reqs.each do |r|
        next if Wedge.loaded_requires.include? r[:name]

        Wedge.loaded_requires << r[:name]

        promises << -> { load_comp r }
      end

      Promise.when(*promises.map!(&:call)).then do
        requires.any?? load_requires(requires, promise) : promise.resolve(true)
      end
    end

    def get_requires reqs, requires_array = []
      new_reqs = []

      reqs.each do |r|
        if r[:requires].any?
          get_requires(r[:requires], requires_array)
        end

        new_reqs << r
      end

      requires_array << new_reqs if new_reqs.any?

      requires_array
    end

    def load_comp options = {}, promise = Promise.new
      path_name  = options[:path_name]
      assets_url = Wedge.assets_url

      # fix: this could give people unwanted behaviour, change getScript to just
      # use ajax.
      `jQuery.ajaxSetup({ cache: true })` if Wedge.opts.cache_assets
      `$.getScript(assets_url + "/" + path_name + ".js").done(function(){`
        promise.resolve true
      `}).fail(function(jqxhr, settings, exception){ window.console.log(exception); });`
      #########################################################################

      promise
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
    def setup(&block)
      block.call config if block_given?
    end

    def config
      @config ||= begin
        args = { klass: self }

        unless RUBY_ENGINE == 'opal'
          args[:file_path]  = caller.first.gsub(/(?<=\.rb):.*/, '')
          args[:assets_key] = begin
            if defined?(Heroku::API) && ENV['HEROKU_TOKEN'] && ENV['HEROKU_APP']
              h = Heroku::API.new(api_key: ENV['HEROKU_TOKEN'])
              h.get_releases(ENV['HEROKU_APP']).body.last['commit']
            else
              `git rev-parse HEAD 2>/dev/null`.to_s.strip
            end
          end
        end

        Config.new(args)
      end
    end

    def opts
      config.opts
    end
  end
end
