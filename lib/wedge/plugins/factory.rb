class Wedge
  module Plugins
    class Factory < Form
      name :factory, :factory_plugin

      def initialize
        class_store[:stubs] ||= IndifferentHash.new
      end

      def stub name, data, keys = false
        class_store[:stubs][name] = parse data, keys
      end

      def [] name
        class_store[:stubs][name]
      end

      private

      def parse data, keys = false
        data        = data.deep_dup
        parsed_data = data.to_h if data.respond_to? :to_h
        parsed_data = IndifferentHash.new JSON.parse data.to_json

        keys.each do |k, v|
          d = data.respond_to?(k) ? data.send(k) : data[k]
          parsed_data[k] = parse d, keys[v]
        end if keys

        parsed_data
      end
    end
  end
end
