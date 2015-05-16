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

class Wedge
  include Methods

  class << self
    attr_accessor :scope, :store

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

    unless RUBY_ENGINE == 'opal'
      def javascript_cache
        @javascript_cache ||= IndifferentHash.new
      end
    end

    if RUBY_ENGINE == 'opal'
      def trigger_browser_events
        config.component_class.each do |k, klass|
          next if klass.config.triggered_browser_events
          klass.config.triggered_browser_events = true

          Wedge.trigger klass.config.name, :browser_events
        end
      end
    end

    def trigger(wedge_name, event_name, *args)
      events.trigger wedge_name, event_name, *args
    end

    def events
      @events ||= Events.new
    end

    # Used to call a component.
    #
    # @example
    #   Browser[:foo].bar
    #
    # @param name [String, Symbol, #to_s] The unique name given to a component.
    # @return [Wedge::Component#method] Last line of the method called.
    def [](name, *args, &block)
      config.component_class[name].wedge_new self, *args, &block
    end

    %w(store scope).each do |meth|
      define_method "#{meth}!" do |value|
        klass = Class.new(self)
        klass.instance_variable_set(:"@config", Wedge.instance_variable_get(:@config))
        klass.instance_variable_set(:"@events", Wedge.instance_variable_get(:@events))
        klass.instance_variable_set(:"@#{meth}", value)
        klass
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
    def javascript(path_name = 'wedge', options = {})
      if server?
        javascript_cache[path_name] ||= begin
          js = build(path_name, options).javascript

          if path_name == 'wedge'
            compiled_data = Base64.encode64 config.client_data.to_json
            # We need to merge in some data that is only set on the server.
            # i.e. path, assets_key etc....
            js << Opal.compile("Wedge.config.data = HashObject.new(JSON.parse(Base64.decode64('#{compiled_data}')).merge Wedge.config.data.to_h)")
            # load all global plugins into wedge
            config.plugins.each do |path|
              js << Wedge.javascript(path)
            end
          end

          js
        end
      else
        url   = "#{Wedge.assets_url_with_host}/#{options[:path]}.js"
        cache = options[:cache_assets]

        `jQuery.ajax({ url: url, dataType: "script", cache: cache }).done(function() {`
          comp = Wedge.store!(options[:store].indifferent)[options[:name]]

          if options[:method_args].any?
            comp.send(options[:method_called], options[:method_args])
          else
            comp.send(options[:method_called])
          end

          Wedge.trigger_browser_events

         `}).fail(function(jqxhr, settings, exception){ window.console.log(exception); })`
      end
    end

    def config
      @config ||= begin
        args = {
          klass: self,
          component_class: IndifferentHash.new,
          requires: IndifferentHash.new
        }

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
