require 'ostruct'

module BrowserIO
  class Config
    # Stores the options for the config
    #
    # @return [OpenStruct]
    attr_accessor :opts

    # Setup initial opts values
    #
    # @param opts [Hash] The initial params for #opts.
    def initialize(opts = {})
      @opts = OpenStruct.new(opts)
    end

    # Set the unique name of the component
    #
    # @param name [<String, Symbol>, #to_sym]
    def name(name)
      @opts.name = name.to_sym
    end
  end
end
