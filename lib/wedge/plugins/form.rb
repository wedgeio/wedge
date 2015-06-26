require_relative 'form/validations'
require_relative 'render'

class Wedge
  module Plugins
    class Form < Component
      name :form_plugin

      attr_reader :_atts, :_options

      include Methods
      include Validations
      include Render

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
        attr_accessor :_atts, :_form
        attr_reader :_options, :_accessors, :_aliases

        def initialize atts, accessors, aliases, options
          @_atts      = atts.kind_of?(Hash) ? HashObject.new(atts) : atts
          @_accessors = accessors
          @_aliases   = aliases
          @_options   = options

          set_atts
          set_accessors

          self
        end

        def set_atts
          atts_hash = {}

          _accessors.each do |att|
            atts_hash[att] = _atts.respond_to?(att) ? _atts.send(att) : nil
          end

          @_atts = HashObject.new atts_hash
        end

        def set_accessors
          _accessors.each do |att|
            att_options = _options[att]
            alias_att   = _aliases[att]

            define_singleton_method att do
              _atts.send(att) if can_read?(att)
            end

            define_singleton_method "#{att}=" do |val, override = false|
              if can_write?(att, override)
                _atts.send("#{att}=", process_value(val, att_options))
              end
            end

            if alias_att
              define_singleton_method(alias_att) { send(att) }
              define_singleton_method("#{alias_att}=") { |val, override = false| send("#{att}=", val, override) }
            end
          end
        end

        def can_read? att
          att_options = _options[att]

          return true if !att_options[:if] && !att_options[:unless]
          return true if att_options[:if] && _form.instance_exec(&att_options[:if])
          return true if att_options[:unless] && !_form.instance_exec(&att_options[:unless])

          false
        end

        def can_write? att, override = false
          att_options = _options[att]

          override || (can_read?(att) && (!att_options[:read_only]))
        end

        def set_defaults _form = self
          @_form = _form

          _accessors.each do |att|
            att_options = _options[att].deep_dup
            default     = att_options[:default]
            default     = _form.instance_exec(&default) if default.kind_of? Proc
            default     = _form.send("default_#{att}") if _form.respond_to? "default_#{att}"

            if form = att_options.delete(:form)
              send("#{att}=", Wedge[
                # name
                "#{form}_form",
                # attributes
                (_atts.respond_to?(att) ? (_atts.send(att) || {}) : {}),
                # options
                { _nested: true }.merge(att_options)
              ])
            elsif default
              send("#{att}=", default, true)
            end
          end

          self
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
        attr_accessor :_accessors, :_accessor_options, :_aliases

        def attr_reader(*attrs, &block)
          default_opts = { read_only: true }
          opts = attrs.pop
          opts.merge!(default_opts) if opts.is_a? Hash

          attrs << opts

          attr_accessor(*attrs, &block)
        end

        def form_accessor name, options = {}
          attr_accessor *[name, { form: name }.merge(options)]
        end

        def attr_accessor(*attrs, &block)
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

        def model_alias alias_name, original_name
          @_aliases ||= IndifferentHash.new
          @_aliases[original_name] = alias_name
          # discuss: should we also alias_method. right now I'm think no, reason
          # being it's just a model alias and shouldn't allow people to call
          # that method on the form to avoid some people using one name and some
          # another.
          # alias_method alias_name, original_name
        end
        alias alias_model model_alias
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
        atts      = atts.deep_dup
        @_options = options.indifferent
        @_atts    = Atts.new atts, _accessors, _aliases, _accessor_options
        @_atts    = @_atts.set_defaults self

        atts.each do |key, val|
          # grab the original key if alias is given
          key = _aliases.invert[key] || key

          next if (_accessor_options[key] || {})[:form]

          accessor = "#{key}="

          if respond_to?(accessor)
            send(accessor, val)
          end
        end
      end

      def _accessors
        @_accessors ||= (self.class._accessors || IndifferentHash.new).deep_dup
      end

      def _accessor_options
        @_accessor_options ||= (self.class._accessor_options || IndifferentHash.new).deep_dup
      end

      def _aliases
        @_aliases || (self.class._aliases || IndifferentHash.new).deep_dup
      end

      def nested?
        @_options[:_nested] ? true : false
      end

      def attributes?
        @_options[:_attributes] ? true : false
      end

      def model_attributes?
        @_options[:_model_attributes] ? true : false
      end

      # Return hash of attributes and values.
      def attributes for_model = false
        IndifferentHash.new.tap do |atts|
          _options[:_attributes]       = true
          _options[:_model_attributes] = for_model
          _accessors.each do |att|
            opts = _accessor_options[att]
            if _atts.can_read?(att) && (!opts[:hidden] || opts[:hidden].is_a?(Proc) && !self.instance_exec(&opts[:hidden]))
              is_form   = opts[:form]
              key       = for_model ? _aliases[att] || att : att
              key       = (for_model && is_form)? "#{key}_attributes" : key
              atts[key] = is_form ? send(att).send(for_model ? 'model_attributes' : 'attributes') : send(att)
            end
          end
        end
      end

      def model_attributes
        attributes true
      end

      alias atts _atts
      alias options _options

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
