require 'browserio/opal'
require 'browserio/version'
require 'browserio/utilis/indifferent_hash'
require 'browserio/utilis/hash'
require 'browserio/utilis/blank'
require 'browserio/utilis/methods'
require 'browserio/utilis/try'
require 'browserio/utilis/titleize'
require 'browserio/utilis/element'
require 'base64'
unless RUBY_ENGINE == 'opal'
  require 'nokogiri'
  require 'browserio/utilis/nokogiri'
end
require 'browserio/html'
require 'browserio/dom'
require 'browserio/config'
require 'browserio/component'

module BrowserIO
  include Methods

  class << self
    attr_accessor :requires, :loaded_requires, :loaded_requires_events, :javascript_cache,
      :bio_javascript_loaded

    def cache
      javascript
    end

    def assets_url
      "#{opts.assets_url}#{opts.cache_assets ? "/#{opts.assets_key}" : ''}"
    end

    def script_tag
      "<script src='#{assets_url}/browserio.js'></script>"
    end

    # Used to call a component.
    #
    # @example
    #   Browser[:foo].bar
    #
    # @param name [String, Symbol, #to_s] The unique name given to a component.
    # @return [BrowserIO::Component#method] Last line of the method called.
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
      def build(path = 'browserio', options = {})
        append_paths
        Opal::Builder.build(path, options)
      end

      # Source maps for the javascript
      def source_map(path = 'browserio', options = {})
        build(path, options).source_map
      end

      # Append the correct paths to opal.
      #
      # @return [Array] List of opal paths.
      def append_paths
        @append_paths ||= begin
          file = method(:components).source_location.first.sub('/browserio.rb', '')
          BrowserIO::Opal.append_path file
          BrowserIO::Opal.append_path Dir.pwd
        end
      end
    end

    # Return the opal javascript.
    def javascript(path_name = 'browserio', options = {}, promise = false)
      if server?
        if path_name == 'browserio'
          @bio_javascript ||= begin
            @bio_javascript_loaded = true
            requires = {}

            @javascript_cache ||= {}

            components.to_h.each do |k, v|
              requires[k] = v.klass.bio_config.get_requires
              javascript(v.klass.bio_opts[:path_name])
            end

            compiled_requires = Base64.encode64 requires.to_json
            assets_key        = opts.assets_key
            cache_assets      = opts.cache_assets

            js = build(path_name, options).javascript
            js << Opal.compile("BrowserIO.instance_variable_set(:@requires, JSON.parse(Base64.decode64('#{compiled_requires}')))")
            # fix: we need to just merge in all config opts and just reject
            # certain ones
            js << Opal.compile("BrowserIO.config.assets_key('#{assets_key}')") if assets_key
            js << Opal.compile("BrowserIO.config.cache_assets('#{cache_assets}')") if cache_assets
            ##############################################################
            js
          end
        else
          @javascript_cache[path_name] ||= begin
            js = build(path_name, options).javascript
            comp_name = components.to_h.select { |k, v| v.path_name == path_name }.first.last.name
            comp = BrowserIO[comp_name]
            options = comp.client_bio_opts
            compiled_opts = Base64.encode64 options.to_json
            js << Opal.compile("BrowserIO.components[:#{comp_name}].klass.instance_variable_set(:@bio_config, BrowserIO::Config.new(BrowserIO.components[:#{comp_name}].klass.bio_config.opts_dup.merge(JSON.parse(Base64.decode64('#{compiled_opts}')))))")
          end
        end
      else
        BrowserIO.loaded_requires ||= []
        BrowserIO.loaded_requires_events ||= []
        reqs     = BrowserIO.requires[options[:name].to_sym].dup
        promise  = Promise.new
        requires = get_requires(reqs)

        load_requires(requires.dup, promise)

        promise.then do
          load_comp(options).then do
            method_called = options[:method_called]
            method_args   = options[:method_args]
            name          = options[:name]
            comp          = BrowserIO[name, options]

            Document.ready? do
              trigger_requires_events requires.dup
              comp.send(method_called, *method_args) if method_called
              comp.bio_trigger :browser_events
            end
          end
        end
      end
    end

    def trigger_requires_events requires
      reqs = requires.shift

      reqs.each do |r|
        next if BrowserIO.loaded_requires_events.include? r[:name]
        BrowserIO.loaded_requires_events << r[:name]
        comp = BrowserIO[r[:name], r]
        comp.bio_trigger :browser_events
      end

      trigger_requires_events requires if requires.any?
    end

    def load_requires requires, promise = Promise.new
      reqs     = requires.shift
      promises = []

      reqs.each do |r|
        next if BrowserIO.loaded_requires.include? r[:name]

        BrowserIO.loaded_requires << r[:name]

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
      assets_url = BrowserIO.assets_url

      # fix: this could give people unwanted behaviour, change getScript to just
      # use ajax.
      `jQuery.ajaxSetup({ cache: true })` if BrowserIO.opts.cache_assets
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
          args[:assets_key] = ENV.fetch('SOURCE_VERSION') { `git rev-parse HEAD 2>/dev/null`.to_s.strip }
        end

        Config.new(args)
      end
    end

    def opts
      config.opts
    end
  end
end
