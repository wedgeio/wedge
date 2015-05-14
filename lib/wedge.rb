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
require 'wedge/events'
require 'wedge/config'
require 'wedge/component'

module Wedge
  include Methods

  class << self
    def assets_url
      url = config.assets_url.gsub(%r{^(http(|s)://[^\/]*\/|\/)}, '/')
      "#{url}#{config.cache_assets ? "/#{config.assets_key}" : ''}"
    end

    def assets_url_with_host
      "#{config.assets_url}#{config.cache_assets ? "/#{config.assets_key}" : ''}"
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
    def [](name, scope, *args, &block)
      wedge_class = config.component_class[name]
      klass = Class.new(wedge_class)
      # need to add the data to this anonymous class
      klass.config.data = HashObject.new wedge_class.config.data.dup
      klass.config.scope = scope

      if args.any?
        klass.new(*args)
      else
        klass.new
      end
    end

    unless RUBY_ENGINE == 'opal'
      # Returns the build object for opal.
      #
      # @param path [String] require path to file to build.
      # @return [String, Opal::Builder#build]
      def build(path = 'wedge', options = {})
        Opal::Builder.build(path, options) if append_paths
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
          file     = method(:assets_url).source_location.first.sub('/wedge.rb', '')
          gems_dir = ::Opal.gem_dir.gsub(/(?<=gems)\/opal-.*/, '')
          Wedge::Opal.append_path file
          Wedge::Opal.append_path Dir.pwd
          Dir["#{gems_dir}/**/"].sort.each do |folder|
            Wedge::Opal.append_path "#{folder}/lib"
          end

          true
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
            js << Opal.compile("Wedge.config.assets_url_with_host('#{opts.assets_url_with_host}')")
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
        Wedge.events_triggered ||= []
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
              if method_called && !comp.wedge_opts.on_server_methods.include?(method_called)
                comp.send(method_called, *method_args)
              end

              unless Wedge.events_triggered.include?(name)
                comp.wedge_trigger :browser_events
                Wedge.loaded_requires << name
                Wedge.events_triggered << name
              end

              trigger_requires_events requires.dup
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
        Wedge.events_triggered << r[:name]
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
      end if reqs

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
      assets_url = Wedge.assets_url_with_host

      if !Wedge.components[options[:name]]
        # fix: this could give people unwanted behaviour, change getScript to just
        # use ajax.
        `jQuery.ajaxSetup({ cache: true })` if Wedge.opts.cache_assets
        `$.getScript(assets_url + "/" + path_name + ".js").done(function(){`
          promise.resolve true
        `}).fail(function(jqxhr, settings, exception){ window.console.log(exception); });`
        #########################################################################
      else
        promise.resolve true
      end

      promise
    end

    def config
      @config ||= begin
        args = { klass: self, component_class: IndifferentHash.new, requires: IndifferentHash.new }

        unless RUBY_ENGINE == 'opal'
          args[:path]       = caller.first.gsub(/(?<=\.rb):.*/, '')
          args[:assets_key] = begin
            if defined?(PlatformAPI) && ENV['HEROKU_TOKEN'] && ENV['HEROKU_APP']
              heroku = PlatformAPI.connect_oauth(ENV['HEROKU_TOKEN'], default_headers: {'Range' => 'version ..; order=desc'})
              slug_id = heroku.release.list(ENV['HEROKU_APP']).first["slug"]["id"]
              heroku.slug.info(ENV['HEROKU_APP'], slug_id)["commit"]
            else
              `git rev-parse HEAD 2>/dev/null`.to_s.strip
            end
          end
        end

        Config.new(args)
      end
    end
  end
end
