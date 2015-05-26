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

class Wedge
  # Create our own opal instance.
  Opal = ::Opal.dup
end

if RUBY_ENGINE == 'opal'
  class Element
    alias_native :mask
    alias_native :remove_data, :removeData
    alias_native :replace_with, :replaceWith
    alias_native :selectize
  end
end

