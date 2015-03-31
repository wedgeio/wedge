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

    if RUBY_ENGINE == 'ruby'
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
    def javascript(name = 'browserio', options = {}, promise = false)
      if server?
        if name == 'browserio'
          @bio_javascript ||= build(name, options).javascript
        else
          js = build(name, options).javascript
          comp_name = components.to_h.select { |k, v| v.path_name == name }.first.last.name
          comp = BrowserIO[comp_name]
          options = comp.client_bio_opts
          compiled_opts = Base64.encode64 options.to_json
          js << Opal.compile("BrowserIO.components[:#{comp_name}].klass.instance_variable_set(:@bio_config, BrowserIO::Config.new(BrowserIO.components[:#{comp_name}].klass.bio_config.opts_dup.merge(JSON.parse(Base64.decode64('#{compiled_opts}')))))")
          js
        end
      else
        opts.loaded ||= {}

        if !opts.loaded.keys.include? name
          opts.loaded[name] = false

          assets_url = options[:assets_url]

          `$.getScript("/" + assets_url + "/" + name + ".js").done(function(){`
            BrowserIO.opts.loaded[name] = true
            method_called = options.delete(:method_called)
            method_args   = options.delete(:method_args)
            name          = options.delete(:name)
            comp          = BrowserIO[name, options]
            requires      = comp.bio_opts.requires

            if requires.present? && requires.first.is_a?(Hash)
              comps = []

              ::Opal::Promise.when(*get_requires(requires, comps)).then do
                comp.send(method_called, *method_args) if method_called
                comp.bio_trigger :browser_events
              end
            else
              comp.send(method_called, *method_args) if method_called
              comp.bio_trigger :browser_events
            end

            promise.resolve true if promise
          `}).fail(function(jqxhr, settings, exception){ window.console.log(exception); });`
        end
      end
    end

    def get_requires requires, reqs = [], from_get = false
      promises = []

      requires.each do |r|
        if r[:requires].any?
          promises << (promise = ::Opal::Promise.new)

          a = []
          c = []

          get_requires(r[:requires], a, true)

          a.each do |re|
            c << -> do
              p = ::Opal::Promise.new

              path_name = re.delete(:path_name)
              BrowserIO.javascript(path_name, re.reject { |k, v| k.to_s == 'requires'}, p)

              p
            end
          end

          ::Opal::Promise.when(*c.map!(&:call)).then do |*args|
            path_name = r.delete(:path_name)
            BrowserIO.javascript(path_name, r.reject { |k, v| k.to_s == 'requires'}, promise)
          end
        else
          reqs << r

          if !from_get
            promises << (promise = ::Opal::Promise.new)

            path_name = r.delete(:path_name)
            BrowserIO.javascript(path_name, r.reject { |k, v| k.to_s == 'requires'}, promise)
          end
        end
      end

      promises
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
      javascript # This pre-compiles the core and store it in mem
      block.call config
    end

    def config
      @config ||= begin
        args = { klass: self }

        if RUBY_ENGINE == 'ruby'
          args[:file_path] = caller.first.gsub(/(?<=\.rb):.*/, '')
        end

        Config.new(args)
      end
    end
    alias_method :config, :config

    def opts
      config.opts
    end
  end
end
