require 'ostruct'

module BrowserIO
  class Config
    include Methods

    # Stores the options for the config
    #
    # @return [OpenStruct]
    attr_accessor :opts

    # Setup initial opts values
    #
    # @param opts [Hash] The initial params for #opts.
    def initialize(opts = {})
      opts = {
        tmpl: IndifferentHash.new,
        scope: false,
        loaded: false
      }.merge opts

      @opts = OpenStruct.new(opts)
    end

    # Set the unique name of the component
    #
    # @param name [<String, Symbol>, #to_sym]
    def name(name)
      opts.name = name.to_sym
      BrowserIO.components ||= {}
      BrowserIO.components[opts.name] = opts
    end

    %w(scope assets_url).each do |m|
      define_method m do |v|
        opts[m] = v
      end
    end

    # Used to set and update the dom
    def dom
      if server?
        yield
      end
    end

    # Set the raw html
    # @param html [String]
    def html(html)
      unless RUBY_ENGINE == 'opal'
        opts.html = begin
          File.read html
        rescue
          html
        end.strip
      end
    end
  end
end
