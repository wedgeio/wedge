class Wedge
  module Plugins
    class Form < Component
      # Provides a base implementation for extensible validation routines.
      # {Scrivener::Validations} currently only provides the following assertions:
      #
      # * assert
      # * assert_present
      # * assert_format
      # * assert_numeric
      # * assert_url
      # * assert_email
      # * assert_member
      # * assert_length
      # * assert_decimal
      # * assert_equal
      #
      # The core tenets that Scrivener::Validations advocates can be summed up in a
      # few bullet points:
      #
      # 1. Validations are much simpler and better done using composition rather
      #    than macros.
      # 2. Error messages should be kept separate and possibly in the view or
      #    presenter layer.
      # 3. It should be easy to write your own validation routine.
      #
      # Other validations are simply added on a per-model or per-project basis.
      #
      # @example
      #
      #   class Quote
      #     attr_accessor :title
      #     attr_accessor :price
      #     attr_accessor :date
      #
      #     def validate
      #       assert_present :title
      #       assert_numeric :price
      #       assert_format  :date, /\A[\d]{4}-[\d]{1,2}-[\d]{1,2}\z
      #     end
      #   end
      #
      #   s = Quote.new
      #   s.valid?
      #   # => false
      #
      #   s.errors
      #   # => { :title => [:not_present],
      #          :price => [:not_numeric],
      #          :date  => [:format] }
      #
      module Validations
        include Methods

        # Check if the current model state is valid. Each call to {#valid?} will
        # reset the {#errors} array.
        #
        # All validations should be declared in a `validate` method.
        #
        # @example
        #
        #   class Login
        #     attr_accessor :username
        #     attr_accessor :password
        #
        #     def validate
        #       assert_present :user
        #       assert_present :password
        #     end
        #   end
        #
        def valid?
          _errors.clear
          validate
          _errors.empty?
        end

        def valid atts
          _set_atts atts
          valid?
        end

        # Base validate implementation. Override this method in subclasses.
        def validate
        end

        def error key, value
          value = [value] unless value.is_a? Array
          _errors[key] = value
        end

        def errors
          IndifferentHash.new(_errors)
        end

        # gives back errors using the model_alias keys
        def model_errors
          IndifferentHash.new(_model_errors)
        end

        # Hash of errors for each attribute in this model.
        def _errors
          @_errors ||= Hash.new do |hash, key|
            data = _accessor_options[key].key?(:form) ? {} : []
            alias_key       = _aliases[key] || key
           _model_errors[alias_key] = hash[key] = data
          end
        end

        def _model_errors
          @_model_errors ||= {}
        end

        protected

        # Allows you to do a validation check against a regular expression.
        # It's important to note that this internally calls {#assert_present},
        # therefore you need not structure your regular expression to check
        # for a non-empty value.
        #
        # @param [Symbol] att The attribute you want to verify the format of.
        # @param [Regexp] format The regular expression with which to compare
        #                 the value of att with.
        # @param [Array<Symbol, Symbol>] error The error that should be returned
        #                                when the validation fails.
        def assert_format(att, format, error = [att, :format])
          if !_atts.send(att).to_s.empty?
            assert(_atts.send(att).to_s.match(format), error)
          end
        end

        # The most basic and highly useful assertion. Simply checks if the
        # value of the attribute is empty.
        #
        # @param [Symbol] att The attribute you wish to verify the presence of.
        # @param [Array<Symbol, Symbol>] error The error that should be returned
        #                                when the validation fails.
        def assert_present(att, error = [att, :not_present])
          if att.is_a? Array
            att.each { |a| assert_present(a, error = [a, :not_present])}
          else
            att_options = _accessor_options[att].deep_dup

            if att_options.key? :form
              assert_form att, error
            else
              assert(!_atts.send(att).to_s.empty?, error)
            end
          end
        end

        def assert_form(att, error = [att, :no_form])
          att_options = _accessor_options[att].deep_dup
          form_name   = att_options.delete :form

          f = wedge("#{form_name}_form", _atts.send(att).attributes, att_options)
          assert(f.valid?, [att, f._errors])
        end

        # Checks if all the characters of an attribute is a digit.
        #
        # @param [Symbol] att The attribute you wish to verify the numeric format.
        # @param [Array<Symbol, Symbol>] error The error that should be returned
        #                                when the validation fails.
        def assert_numeric(att, error = [att, :not_numeric])
          # discuss: I commented this out as I don't think we should assume they
          # want to validate presents if they validate for numeric. if they
          # validate for numeric.
          # if assert_present(att, error)
          if !_atts.send(att).to_s.empty?
            if client?
              assert_format(att, /^\-?\d+$/, error)
            else
              assert_format(att, /\A\-?\d+\z/, error)
            end
          end
        end

        if client?
          URL = /^(http|https):\/\/([a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}|(25[0-5]|2[0-4]\d|[0-1]?\d?\d)(\.(25[0-5]|2[0-4]\d|[0-1]?\d?\d)){3}|localhost)(:[0-9]{1,5})?(\/.*)?$/i
        else
          URL = /\A(http|https):\/\/([a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}|(25[0-5]|2[0-4]\d|[0-1]?\d?\d)(\.(25[0-5]|2[0-4]\d|[0-1]?\d?\d)){3}|localhost)(:[0-9]{1,5})?(\/.*)?\z/i
        end

        def assert_url(att, error = [att, :not_url])
          if !_atts.send(att).to_s.empty?
            assert_format(att, URL, error)
          end
        end

        if client?
          EMAIL = /^[a-z0-9!\#$%&'*\/=\?^{|}+_-]+(?:\.[a-z0-9!\#$%&'*\/=\?^{|}+_-]+)*@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$/i
        else
          EMAIL = /\A[a-z0-9!\#$%&'*\/=\?^{|}+_-]+(?:\.[a-z0-9!\#$%&'*\/=\?^{|}+_-]+)*@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\z/i
        end

        def assert_email(att, error = [att, :not_email])
          if !_atts.send(att).to_s.empty?
            assert_format(att, EMAIL, error)
          end
        end

        def assert_member(att, set, err = [att, :not_valid])
          assert(set.include?(_atts.send(att)), err)
        end

        def assert_length(att, range, error = [att, :not_in_range])
          if !_atts.send(att).to_s.empty?
            val = _atts.send(att).to_s
            assert range.include?(val.length), error
          end
        end

        if client?
          DECIMAL = /^\-?(\d+)?(\.\d+)?$/
        else
          DECIMAL = /\A\-?(\d+)?(\.\d+)?\z/
        end

        def assert_decimal(att, error = [att, :not_decimal])
          assert_format att, DECIMAL, error
        end

        # Check that the attribute has the expected value. It uses === for
        # comparison, so type checks are possible too. Note that in order
        # to make the case equality work, the check inverts the order of
        # the arguments: `assert_equal :foo, Bar` is translated to the
        # expression `Bar === send(:foo)`.
        #
        # @example
        #
        #   def validate
        #     assert_equal :status, "pending"
        #     assert_equal :quantity, Fixnum
        #   end
        #
        # @param [Symbol] att The attribute you wish to verify for equality.
        # @param [Object] value The value you want to test against.
        # @param [Array<Symbol, Symbol>] error The error that should be returned
        #                                when the validation fails.
        def assert_equal(att, value, error = [att, :not_equal])
          assert value === _atts.send(att), error
        end

        # The grand daddy of all assertions. If you want to build custom
        # assertions, or even quick and dirty ones, you can simply use this method.
        #
        # @example
        #
        #   class CreatePost
        #     attr_accessor :slug
        #     attr_accessor :votes
        #
        #     def validate
        #       assert_slug :slug
        #       assert votes.to_i > 0, [:votes, :not_valid]
        #     end
        #
        #   protected
        #     def assert_slug(att, error = [att, :not_slug])
        #       assert send(att).to_s =~ /\A[a-z\-0-9]+\z/, error
        #     end
        #   end
        def assert(value, error)
          value or begin
            name   = error.shift.to_s
            atts   = _accessor_options[name][:atts] || false
            error  = atts ? error.first.select {|k, _| atts.include?(k) } : error
            errors = _errors[name]

            if errors.is_a?(Array)
              errors.concat(error) && false
            else
              errors.merge!(error.is_a?(Array) ? error.first : error) && false
            end

            false
          end
        end
      end
    end
  end
end
