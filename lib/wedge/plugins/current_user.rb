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
          code = File.read("#{Dir.pwd}/#{Wedge.config.app_dir}/#{path}.rb")
          config.compile_str << Opal.original_compile("require 'wedge/plugins/#{type}'; #{code}")
        end if for_client
      end

      module InstanceMethods
        def wedge_current_user
          @wedge_current_user ||= Wedge[:current_user, wedge(:current_user_plugin).get_current_user]
        end
        alias_method :current_user, :wedge_current_user
      end

      on :server do
        def get_current_user
          attributes    = Wedge[:current_user, instance_exec(&Wedge[:current_user_plugin].config.block) || {}].attributes
          client_fields = config.settings[:client_fields]

          from_client?? attributes.select { |k, v| client_fields.include? k } : attributes
        end
      end

      def abilities
        @abilities ||= Wedge[:ability_list, self]
      end
    end
  end
end
