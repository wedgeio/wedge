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
require 'forwardable'
unless RUBY_ENGINE == 'opal'
  require 'nokogiri'
  require 'wedge/utilis/nokogiri'
  require 'wedge/middleware'
end
require 'wedge/html'
require 'wedge/dom'
require 'wedge/events'
require 'wedge/config'
require 'wedge/component'

class Wedge
  include Methods

  class << self
    extend Forwardable

    ATTR_ACCESSORS = %i{scope store config events}

    attr_accessor(*ATTR_ACCESSORS)

    delegate [:plugin] => :config

    def assets_url
      url = config.assets_url.gsub(%r{^(http(|s)://[^\/]*\/|\/)}, '/')
      "#{url}#{config.cache_assets ? "/#{config.assets_key}" : ''}"
    end

    def assets_url_regex
      @assets_url_regex ||= begin
        assets_url = ::Wedge.assets_url.gsub(%r{^\/}, '')
        # # We also allow for no assets key so when we post server methods there
        # # isn't an error if the key has been changed since a browser refresh.
        %r{(?:#{assets_url}|#{assets_url.sub("#{::Wedge.config.assets_key}/", '')})/(.*)\.(.*)$}
      end
    end

    def assets_url_with_host
      "#{config.assets_url}#{config.cache_assets ? "/#{config.assets_key}" : ''}"
    end

    def html!(scope = false, &block)
      if !block_given?
        html = HTML::DSL.html(&scope).to_html
      else
        html = HTML::DSL.scope!(scope).html(&block).to_html
      end

      DOM.new html
    end

    def script_tag
      "<script src='#{assets_url_with_host}/wedge.js'></script>"
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
    def [](*args, &block)
      config.component_class[args.shift].wedge_new self, *args, &block
    end

    %w(store scope).each do |meth|
      define_method "#{meth}!" do |value|
        klass = Class.new(self)
        ATTR_ACCESSORS.each do |name|
          klass.instance_variable_set(:"@#{name}", Wedge.instance_variable_get(:"@#{name}").deep_dup)
        end
        klass.instance_variable_set(:"@#{meth}", value.deep_dup)
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
          Wedge::Opal.append_path method(:assets_url).source_location.first.sub('/wedge.rb', '')
          Wedge::Opal.append_path "#{Dir.pwd}/#{config.app_dir}"
        end
      end
    end

    # Return the opal javascript.
    def javascript(path_name = 'wedge', options = {})
      path_name = path_name.to_s

      if server?
        javascript_cache[path_name] ||= begin
          build(path_name, options).to_s
        end
      else
        url   = "#{Wedge.assets_url_with_host}/#{options[:path]}.js"
        cache = options[:cache_assets]

        `jQuery.ajax({ url: url, dataType: "script", cache: cache }).done(function() {`
          # fix: at the moment to_js called from the server will set the class
          # store for whatever method it calls.  we need to think of a better idea
          # for global and local data store.
          Wedge.config.component_class[options[:name]].config.store = options[:store].indifferent

          if initialize_args = options.delete(:initialize_args)
            comp = Wedge[options[:name], *initialize_args]
          else
            comp = Wedge[options[:name]]
          end

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
        args = { component_class: IndifferentHash.new }

        unless RUBY_ENGINE == 'opal'
          args[:path]       = method(:assets_url).source_location.first.sub('/wedge.rb', '')
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
