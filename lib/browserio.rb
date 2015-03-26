require 'browserio/opal'
require 'browserio/version'
require 'browserio/utilis/indifferent_hash'
require 'browserio/utilis/hash'
require 'browserio/utilis/blank'
require 'browserio/utilis/methods'
require 'browserio/utilis/try'
require 'browserio/utilis/titleize'
require 'base64'
require 'nokogiri' unless RUBY_ENGINE == 'opal'
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
    def javascript(name = 'browserio', options = {})
      if server?
        if name == 'browserio'
          @bio_javascript ||= build(name, options).javascript
        else
          js = build(name, options).javascript
          comp_name = components.to_h.select { |k, v| v.path_name == name }.first.last.name
          comp = BrowserIO[comp_name]
          options = comp.client_bio_opts
          compiled_opts = Base64.encode64 options.to_json
          js
        end
      else
        promise = Promise.new

        if !components[name.to_sym]
          components[name.to_sym] = 'loading'

          assets_url = options[:assets_url]

          `$.getScript("" + assets_url + "/" + name + ".js").done(function(){`
            options[:loaded] = true
            method_called = options.delete(:method_called)
            method_args   = options.delete(:method_args)
            name          = options.delete(:name)
            comp          = BrowserIO[name, options]
            requires      = comp.bio_opts.requires

            if requires.present? && requires.first.is_a?(Hash)
              comps = []
              requires.each do |o|
                comps << -> do
                  path_name = o.delete(:path_name)
                  BrowserIO.javascript(path_name, o)
                end
              end

              Promise.when(*comps.map!(&:call)).then do |*args|
                comp.send(method_called, *method_args) if method_called
                comp.bio_trigger :browser_events
                promise.resolve true
              end
            else
              comp.send(method_called, *method_args) if method_called
              comp.bio_trigger :browser_events
              promise.resolve true
            end
          `}).fail(function(jqxhr, settings, exception){ window.console.log(exception); });`
        else
          promise.resolve true
        end

        promise
      end
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
