module BrowserIO
  module Methods
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def client?
        RUBY_ENGINE == 'opal'
      end

      def server?
        RUBY_ENGINE == 'ruby'
      end
    end

    def server?
      self.class.server?
    end

    def client?
      self.class.client?
    end
  end
end
