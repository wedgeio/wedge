require 'opal'
require 'opal-jquery'

unless RUBY_ENGINE == 'opal'
  module Opal
    class Builder
      # @return [String] Compiled javascript.
      def javascript
        to_s
      end
    end
  end
end

module Wedge
  # Create our own opal instance.
  Opal = ::Opal.dup
end
