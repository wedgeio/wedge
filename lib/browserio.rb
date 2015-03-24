require 'browserio/version'
require 'browserio/opal'
require 'nokogiri' unless RUBY_ENGINE == 'opal'
require 'browserio/methods'
require 'browserio/html'
require 'browserio/dom'
require 'browserio/config'
require 'browserio/component'

module BrowserIO
  class << self
    # Stores all the components.
    #
    # @return [OpenStruct]
    attr_accessor :components

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

    if RUBY_ENGINE == 'ruby'
      # Returns the build object for opal.
      #
      # @param path [String] require path to file to build.
      # @return [String, Opal::Builder#build]
      def build(path = 'browserio')
        append_paths
        Opal::Builder.build(path)
      end

      # Source maps for the javascript
      def source_map
        build.source_map
      end

      # Return the opal javascript.
      def javascript
        build.javascript
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
  end
end
