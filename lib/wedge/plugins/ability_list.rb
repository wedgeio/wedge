require 'wedge/plugins/form'

class Wedge
  module Plugins
    class AbilityList < Form
      name :ability_list_plugin

      Error = Class.new(StandardError)

      # Returns a list of rules. These are populated by `can` and `cannot`.
      # (Rules are tuples)
      def rules
        @rules ||= []
      end

      # ---

      # Declares that the owner can perform `verb` on `class`.
      def can(verb, klass=nil, columns=[], &block)
        columns = [columns] unless columns.is_a? Array
        rules << [true, verb, get_class(klass), columns, block]
      end

      # Inverse of `can`.
      def cannot(verb, klass=nil, columns=[], &block)
        columns = [columns] unless columns.is_a? Array
        rules << [false, verb, get_class(klass), columns, block]
      end

      # ---

      # Checks if the owner can perform `verb` on the given `object` (or class).
      def can?(verb, object=nil, columns=[])
        columns = [columns] unless columns.is_a? Array
        rules = rules_for(verb, get_class(object))
        rules.inject(false) do |bool, (sign, _, _, cols, proc)|
          sign ?
            ((bool || !proc ||  proc.call(object)) && ((columns & cols) == columns)) :  # can
            (bool &&  proc && !proc.call(object) && (columns.empty? || (columns & cols) != columns))    # cannot
        end
      end

      # Inverse of `can?`.
      def cannot?(verb, object=nil, columns=[])
        !can?(verb, object, columns)
      end

      # ---

      # Ensures that the owner can perform `verb` on `object/class` -- raises an
      # error otherwise.
      def authorize!(verb, object=nil)
        can?(verb, object) or raise Error.new("Access denied (#{verb})")
      end

      # Inverse of `authorize!`.
      def unauthorize!(verb, object=nil)
        cannot?(verb, object) or raise Error.new("Access denied (#{verb})")
      end

      # ---

      # Returns a subset of `rules` that match the given `verb` and `class`.
      def rules_for(verb, klass)
        rules.select do |(sign, _verb, _klass, cols, block)|
          (_verb  == :manage || _verb  == verb) &&
          (_klass == :all    || _klass == klass)
        end
      end

    private

      def get_class_name(klass)
        if !klass.is_a?(Symbol) && klass.respond_to?(:original_class_name)
          klass.original_class_name
        else
          [NilClass, Symbol].include?(klass.class) ? klass : klass.name
        end
      end

      def get_class(object)
        if object.class.respond_to?(:original_class) && object.class.original_class
          object.class.original_class
        else
          [NilClass, Symbol, Class].include?(object.class) ? object : object.class
        end
      end
    end

    # Provides `#can?` and `#cannot?` and other helpers.
    # Assumes that you have an `#ability` method defined.
    module AbilityList::Helpers
      def can?(*a)
        abilities && abilities.can?(*a)
      end

      def cannot?(*a)
        !abilities || abilities.cannot?(*a)
      end

      def authorize!(*a)
        raise AbilityList::Error.new("No 'ability' defined") unless abilities
        abilities.authorize!(*a)
      end
    end
  end
end
