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
