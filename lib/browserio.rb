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
    attr_accessor :requires

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
    def javascript(path_name = 'browserio', options = {}, promise = false)
      if server?
        if path_name == 'browserio'
          @bio_javascript ||= begin
            requires = {}

            components.to_h.each do |k, v|
              requires[k] = v.klass.bio_config.get_requires
            end

            compiled_requires = Base64.encode64 requires.to_json

            js = build(path_name, options).javascript
            js << Opal.compile("BrowserIO.instance_variable_set(:@requires, JSON.parse(Base64.decode64('#{compiled_requires}')))")
            js
          end
        else
          js = build(path_name, options).javascript
          comp_name = components.to_h.select { |k, v| v.path_name == path_name }.first.last.name
          comp = BrowserIO[comp_name]
          options = comp.client_bio_opts
          compiled_opts = Base64.encode64 options.to_json
          js << Opal.compile("BrowserIO.components[:#{comp_name}].klass.instance_variable_set(:@bio_config, BrowserIO::Config.new(BrowserIO.components[:#{comp_name}].klass.bio_config.opts_dup.merge(JSON.parse(Base64.decode64('#{compiled_opts}')))))")
          js
        end
      else
        opts.loaded ||= {}

        assets_url    = options[:assets_url]
        method_called = options.delete(:method_called)
        method_args   = options.delete(:method_args)
        name          = options.delete(:name)
        reqs          = BrowserIO.requires[name.to_sym].dup

        if !opts.loaded.keys.include? path_name
          opts.loaded[path_name] = false

          if reqs.present? && reqs.first.is_a?(Hash)
            ::Opal::Promise.when(*get_requires(reqs)).then do
              `$.getScript("/" + assets_url + "/" + path_name + ".js").done(function(){`
                opts.loaded[path_name] = true

                comp = BrowserIO[name, options]
                comp.send(method_called, *method_args) if method_called
                comp.bio_trigger :browser_events

                promise.resolve true if promise
              `}).fail(function(jqxhr, settings, exception){ window.console.log(exception); });`
            end
          else
            `$.getScript("/" + assets_url + "/" + path_name + ".js").done(function(){`
              opts.loaded[path_name] = true

              comp = BrowserIO[name, options]
              comp.send(method_called, *method_args) if method_called
              comp.bio_trigger :browser_events

              promise.resolve true if promise
            `}).fail(function(jqxhr, settings, exception){ window.console.log(exception); });`
          end
        end
      end
    end

    def get_requires reqs
      promises = []

      reqs.each do |r|
        promises << (promise = (r[:promise] ||= Promise.new))

        if r[:requires].any?
          Promise.when(*get_requires(r[:requires])).then do |*args|
            path_name = r.delete(:path_name)
            BrowserIO.javascript(path_name, r, promise)
          end
        else
          path_name = r.delete(:path_name)
          BrowserIO.javascript(path_name, r, promise)
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

        unless RUBY_ENGINE == 'opal'
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
