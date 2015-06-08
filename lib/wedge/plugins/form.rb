require_relative 'form/validations'
require 'forwardable'

class Wedge
  module Plugins
    class Form < Component
      name :form_plugin

      attr_reader :_atts

      include Methods
      include Validations

      # This allows us to call super
      module Delegates
        def _delegates(*names)
          accessors = Module.new do
            extend Forwardable

            names.each do |name|
              delegate [name, "#{name}="] => :_atts
            end
          end
          include accessors
        end
      end

      extend Delegates

      class Atts
        attr_accessor :atts
        attr_reader :options, :accessors, :form

        def initialize atts, accessors, options, form
          @atts      = atts.kind_of?(Hash) ? HashObject.new(atts) : atts
          @form      = form
          @accessors = accessors
          @options   = options

          set_atts
          set_accessors
          set_defaults

          self
        end

        def set_atts
          atts_hash = {}

          accessors.each do |att|
            atts_hash[att] = atts.respond_to?(att) ? atts.send(att) : nil
          end

          @atts = HashObject.new atts_hash
        end

        def set_accessors
          accessors.each do |att|
            att_options = options[att]

            define_singleton_method att do
              atts.send att
            end

            define_singleton_method "#{att}=" do |val, override = false|
              if !att_options[:read_only] || (att_options[:read_only] && override)
                atts.send("#{att}=", process_value(val, att_options))
              end
            end
          end
        end

        def set_defaults
          accessors.each do |att|
            att_options = options[att].deep_dup
            default     = att_options[:default]
            default     = self.instance_exec(&default) if default.kind_of? Proc
            default     = form.send("default_#{att}") if form.respond_to? "default_#{att}"

            if form = att_options.delete(:form)
              send("#{att}=", Wedge[
                # name
                "#{form}_form",
                # attributes
                (atts.respond_to?(att) ? (atts.send(att) || {}) : {}),
                # options
                att_options
              ])
            elsif default
              send("#{att}=", default, true)
            end
          end
        end

        def process_value val, opts
          # Make sure the value is the correct type
          if type = opts[:type]
            val = case type
            when 'Integer'
              val.to_i
            when 'String'
              val.to_s
            when 'Symbol'
              val.to_sym
            end
          end

          val
        end
      end

      class << self
        attr_accessor :_accessors, :_accessor_options

        def attr_reader(*attrs)
          default_opts = { read_only: true }
          opts = attrs.pop
          opts.merge!(default_opts) if opts.is_a? Hash

          attrs << opts

          attr_accessor(*attrs)
        end

        def form_accessor name, options = {}
          attr_accessor *[name, options.merge(form: name)]
        end

        def attr_accessor(*attrs)
          attrs.each_with_index do |att, i|
            if att.is_a? Hash
              # remove the hash from the attrs, use them as options
              options = attrs.delete_at i
              # set the type class to aa string so it's not turned into an
              # anonymous class
              if type = options.delete(:type)
                options[:type] = type.to_s
              end
              # merge and att them to the accessor options
              attrs.each do |a|
                ((@_accessor_options ||= IndifferentHash.new)[a] ||= {}).merge! options
              end
            else
              # set empty options if need be
              (@_accessor_options ||= IndifferentHash.new)[att] ||= {}
              # store the accessors
              ((@_accessors ||= []) << att).uniq!
              define_method(att) { _atts.send att }
            end
          end

          _delegates(*attrs)
        end

        # We need to set instance variables on the inherited class
        def inherited(subclass)
          return if name == 'Wedge::Plugins::Form'

          subclass.instance_variable_set :@_accessors, @_accessors.deep_dup
          subclass.instance_variable_set :@_accessor_options, @_accessor_options.deep_dup
        end
      end

      # Initialize with a hash of attributes and values.
      # Extra attributes are discarded.
      #
      # @example
      #
      #   class EditPost < Scrivener
      #     attr_accessor :title
      #     attr_accessor :body
      #
      #     def validate
      #       assert_present :title
      #       assert_present :body
      #     end
      #   end
      #
      #   edit = EditPost.new(title: "Software Tools")
      #
      #   edit.valid? #=> false
      #
      #   edit.errors[:title] #=> []
      #   edit.errors[:body]  #=> [:not_present]
      #
      #   edit.body = "Recommended reading..."
      #
      #   edit.valid? #=> true
      #
      #   # Now it's safe to initialize the model.
      #   post = Post.new(edit.attributes)
      #   post.save
      def initialize(atts = {}, options = {})
        @_atts = Atts.new atts, _accessors, _accessor_options, self

        atts.each do |key, val|
          next if _accessor_options[key][:form]

          accessor = "#{key}="

          if respond_to?(accessor)
            send(accessor, val)
          end
        end
      end

      def _accessors
        @_accessors ||= self.class._accessors.dup
      end

      def _accessor_options
        @_accessor_options ||= self.class._accessor_options.deep_dup
      end

      # Return hash of attributes and values.
      def attributes
        IndifferentHash.new.tap do |atts|
          _accessors.each do |att|
            is_form   = _accessor_options[att][:form]
            atts[att] = is_form ? send(att).attributes : send(att)
          end
        end
      end

      def slice(*keys)
        IndifferentHash.new.tap do |atts|
          keys.each do |att|
            atts[att] = send(att)
          end
        end
      end
    end
  end
end
