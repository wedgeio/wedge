require 'wedge/plugins/form'

class Wedge
  module Plugins
    class CurrentUser < Form
      plugin :ability_list

      include AbilityList::Helpers

      name :current_user_plugin

      on :compile do |for_client|
        # todo: raise error meaningful error if either of these files don't exist
        %w'ability_list current_user'.each do |type|
          config.compile_str ||= ''
          path = Wedge.config.component_class[:"#{type}"].config.path
          config.compile_str << Wedge.javascript(path)
        end if for_client
      end

      module InstanceMethods
        def wedge_current_user &block
          if block_given?
            wedge(:current_user_plugin).get_current_user do |data|
              block.call data
              Store[:current_user] ||= Wedge[:current_user, data]
            end
          else
            Store[:current_user] ||= Wedge[:current_user, wedge(:current_user_plugin).get_current_user]
          end
        end
        alias_method :current_user, :wedge_current_user
      end

      on :server do
        def get_current_user
          data = instance_exec(&Wedge[:current_user_plugin].config.block) || {}

          if from_client?
            Wedge[:current_user, data].attributes
          else
            data
          end
        end
      end

      def abilities
        @abilities ||= Wedge[:ability_list, self]
      end
    end
  end
end
