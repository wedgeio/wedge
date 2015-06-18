class Wedge
  module Plugins
    class Factory < Form
      name :factory, :factory_plugin

      def initialize
        class_store[:stubs] ||= IndifferentHash.new
      end

      def stub data, name, keys = false
        class_store[:stubs][name] = parse data, keys
      end

      def [] name, data = {}
        data = IndifferentHash.new(data)
        store_data = IndifferentHash.new class_store[:stubs][name].deep_dup
        HashObject.new store_data.merge data
      end

      private

      def parse data, keys = false
        data        = data.deep_dup
        parsed_data = data.to_h if data.respond_to? :to_h
        parsed_data = JSON.parse data.to_json

        keys.each do |k, v|
          d = data.kind_of?(Hash) ? data[k] : data.send(k)
          parsed_data[k] = parse d, v
        end if keys

        parsed_data
      end
    end
  end
end
