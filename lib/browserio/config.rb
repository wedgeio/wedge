module BrowserIO
  class Config
    attr_accessor :settings

    def initialize *args
      @settings = OpenStruct.new(*args)
    end

    def name(name)
      @settings.name = name
    end
  end
end
