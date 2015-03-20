require 'opal'
require 'opal-jquery'

if RUBY_ENGINE == 'ruby'
  module Opal
    class Builder
      # @return [String] Compiled javascript.
      def javascript
        to_s
      end
    end
  end
end

module BrowserIO
  # Create our own opal instance.
  Opal = ::Opal.dup
end
