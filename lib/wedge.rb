unless RUBY_ENGINE == 'opal'
  require 'opal'
  Opal.append_path File.expand_path('../', __FILE__).untaint
end

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
  require 'wedge/opal'
  require 'nokogiri'
  require 'wedge/utilis/nokogiri'
  require 'wedge/middleware'
end
require 'wedge/store'
require 'wedge/html'
require 'wedge/dom'
require 'wedge/events'
require 'wedge/config'
require 'wedge/component'
require 'wedge/railtie' if RUBY_ENGINE != 'opal' && defined?(Rails::Railtie)

class Wedge
  include Methods

  class << self
    extend Forwardable

    ATTR_ACCESSORS = %i{scope store config events method_called}

    attr_accessor(*ATTR_ACCESSORS)

    delegate [:plugin] => :config

    def load_settings settings
      return unless settings

      case settings
      when Proc
        Wedge.config.instance_eval &settings
      else
        settings.each { |k, v| Wedge.config.send "#{k}=", v }
      end

      Wedge.config.opal = { server: Wedge::Opal::Server.new { |s|
        s.append_path "#{Dir.pwd}/#{Wedge.config.app_dir}"
        s.prefix  = Wedge.assets_url
        s.debug   = Wedge.config.debug
        s.headers = Wedge.config.assets_headers
        s.gzip    = Wedge.config.gzip_assets
      }}

      if Wedge.config.debug
        Wedge.config.opal[:sprockets]   = Wedge.config.opal[:server].sprockets
        Wedge.config.opal[:maps_prefix] = "#{Wedge.assets_url}/__OPAL_SOURCE_MAPS__"
        Wedge.config.opal[:maps_app]    = Opal::SourceMapServer.new Wedge.config.opal[:sprockets], Wedge.config.opal[:maps_prefix]

        Wedge::Opal::Sprockets::SourceMapHeaderPatch.inject! Wedge.config.opal[:maps_prefix]
      end
    end

    def assets_url
      url = config.assets_url.gsub(%r{^(http(|s)://[^\/]*\/|\/)}, '/')
      url.gsub /\n/, ''
    end

    def assets_url_regex
      @assets_url_regex ||= begin
        assets_url = ::Wedge.assets_url.gsub(%r{^\/}, '')
        # # We also allow for no assets key so when we post server methods there
        # # isn't an error if the key has been changed since a browser refresh.
        %r{(?:/|)#{assets_url}/(.*)\.(.*)$}
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

    unless RUBY_ENGINE == 'opal'
      # def script_tag
      #   # note: ?body=1 is a hack for sprockets to make source maps work # correctly.
      #   "<script src='#{assets_url_with_host}/wedge.js#{Wedge.config.debug ? '?body=1' : ''}' type='text/javascript'></script>"
      # end

      def script_tag name = 'wedge'
        sprockets = Wedge.config.opal[:server].sprockets
        asset = sprockets[name]
        raise "Cannot find asset: #{name}" if asset.nil?
        scripts = []

        get_asset_urls(name).each do |url|
          scripts << %{<script src="#{url}"></script>}
        end

        scripts << %{<script>#{Wedge::Opal::Sprockets.load_asset(name, sprockets)}</script>}

        scripts.join "\n"
      end

      def get_asset_urls name
        sprockets = Wedge.config.opal[:server].sprockets
        prefix = Wedge.assets_url_with_host
        asset = sprockets[name]
        raise "Cannot find asset: #{name}" if asset.nil?
        urls = []

        if Wedge.config.opal[:server].debug
          asset.to_a.map do |dependency|
            urls << %{#{prefix}/#{dependency.logical_path}?body=1}
          end
        else
          urls << %{#{prefix}/#{name}.js}
        end

        urls
      end

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
      name = args.shift
      config.component_class[name.to_sym].wedge_new self, *args, &block
    end

    %w(store scope).each do |meth|
      define_method "#{meth}!" do |value, method_called = nil|
        klass = Class.new(self)
        ATTR_ACCESSORS.each do |name|
          klass.instance_variable_set(:"@#{name}", Wedge.instance_variable_get(:"@#{name}").deep_dup)
        end
        klass.instance_variable_set(:"@#{meth}", value.deep_dup)
        klass.instance_variable_set(:"@method_called", method_called) if meth.to_s == 'scope'
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

          true
        end
      end
    end

    # Return the opal javascript.
    def javascript(path_name = 'wedge', options = {}, url = false)
      path_name = path_name.to_s

      if server?
        javascript_cache[path_name] ||= begin
          build(path_name, options).to_s
        end
      else
        trigger_javascript_loaded path_name, options
      end
    end

    def trigger_javascript_loaded path_name, options
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
    end

    def create_assets_key
      o = [('a'..'z'), ('A'..'Z')].map { |i| i.to_a }.flatten
      key = (0...50).map { o[rand(o.length)] }.join
      ::FileUtils.mkdir_p(File.dirname('.wedge_assets_key'))
      ::File.open('.wedge_assets_key', 'wb'){|f| f.write(key) }
      config.assets_key = key
    end

    def config
      @config ||= begin
        args = { component_class: IndifferentHash.new }

        unless RUBY_ENGINE == 'opal'
          args[:path]       = method(:assets_url).source_location.first.sub('/wedge.rb', '')
          args[:assets_key] = ::File.exist?('.wedge_assets_key') ? ::File.read('.wedge_assets_key') : nil
        end

        Config.new(args)
      end
    end
  end
end
