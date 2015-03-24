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
        tmpl: OpenStruct.new
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

    def dom
      yield
    end

    def html(html)
      return unless server?

      opts.html = begin
        File.read html
      rescue
        html
      end.strip
    end
  end
end
