class Wedge
  module HTML
    include Methods

    INDENT = '  '

    class << self
      # Parse HTML into a Nokogiri object
      # @param raw_html [String]
      # @return parsed_html [Nokogiri]
      def [](raw_html)
        return unless server?

        # remove all the starting and trailing whitespace
        raw_html = raw_html.strip

        if raw_html[/\A<!DOCTYPE/] || raw_html[/\A<html/]
          Nokogiri::HTML(raw_html)
        else
          parsed_html = Nokogiri::HTML.fragment(raw_html)

          if parsed_html.children.length >= 1
            parsed_html.children.first
          else
            parsed_html
          end
        end
      end
    end

    # http://erikonrails.snowedin.net/?p=379
    class DSL
      def initialize(tag, *args, &block)
        @tag = tag
        @content = args.find {|a| a.instance_of? String}
        @attributes = args.find{|a| a.instance_of? Hash}
        @attr_string = []
        self.instance_eval &block if block_given?
      end

      def to_html
        @attr_string << " #{@attributes.map {|k,v| "#{k}=#{v.to_s.inspect}" }.join(" ")}" if @attributes
        "<#{@tag}#{@attr_string.join}>#{@content}#{children.map(&:to_html).join}</#{@tag}>"
      end

      def children
        @children ||= []
      end

      # Some of these are Kernel or Object methods or whatever that we need to explicitly override
      [:p, :select].each do |name|  
        define_method name do |*args, &block|
          send :method_missing, name, *args, &block
        end
      end

      def method_missing(tag, *args, &block)
        if scope.respond_to?(tag, true)
          scope.send(tag, *args, &block)
        else
          child = DSL.scope!(scope).new(tag.to_s, *args, &block)
          children << child
          child
        end
      end

      def scope
        self.class.scope
      end

      class  << self
        attr_accessor :scope

        def method_missing(tag, *args, &block)
          DSL.scope!(scope).new(tag.to_s, *args, &block)
        end

        def scope! scope
          klass = Class.new(self)
          klass.instance_variable_set(:@scope, scope)
          klass
        end
      end
    end
  end
end
