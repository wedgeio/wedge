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
    attr_accessor :requires, :loaded_requires

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
        BrowserIO.loaded_requires ||= []
        reqs = BrowserIO.requires[options[:name].to_sym].dup

        load_requires get_requires(reqs)
      end
    end

    def load_requires requires
      reqs     = requires.shift
      promises = []

      reqs.each do |r|
        next if BrowserIO.loaded_requires.include? r[:name]

        BrowserIO.loaded_requires << r[:name]

        promises << -> do
          promise   = ::Opal::Promise.new
          path_name = r.delete(:path_name)

          load_comp path_name, promise, r
        end
      end

      Promise.when(*promises.map!(&:call)).then do
        load_requires requires
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

    def load_comp path_name, promise = Promise.new, options = {}
      assets_url    = options[:assets_url]
      # name          = options[:name]

      `$.getScript("/" + assets_url + "/" + path_name + ".js").done(function(){`
        # comp = BrowserIO[name, options]
        # comp.send(method_called, *method_args) if method_called
        # comp.bio_trigger :browser_events

        promise.resolve true
      `}).fail(function(jqxhr, settings, exception){ window.console.log(exception); });`

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
