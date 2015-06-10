class Wedge
  module Plugins
    class CurrentUser < Form
      include AbilityList::Helpers

      name :current_user_plugin

      on :compile do |for_client|
        obj           = instance_exec(&config.block)
        client_fields = config.settings[:client_fields]
        store[:user]  = obj.select do |k, v|
          for_client ? (client_fields ||= []).include?(k.to_s) : true
        end

        if for_client
          config.compile_str = ''

          # todo: raise error meaningful error if either of these files don't exist
          %w'ability_list current_user'.each do |type|
            path = Wedge.config.component_class[:"#{type}"].config.path
            code = File.read("#{Dir.pwd}/#{Wedge.config.app_dir}/#{path}.rb")
            config.compile_str << Opal.original_compile("require 'wedge/plugins/#{type}'; #{code}")
          end
        end
      end

      module ClassMethods
        def current_user
          Wedge[:current_user]
        end
      end

      module InstanceMethods
        def current_user
          Wedge[:current_user]
        end
      end

      def abilities
        @abilities ||= Wedge[:ability_list, self]
      end

      def initialize atts = {}, options = {}
        if self.class.name == 'Wedge::Plugins::CurrentUser'
          super
        else
          super Wedge[:current_user_plugin].store[:user], options
        end
      end
    end
  end
end
