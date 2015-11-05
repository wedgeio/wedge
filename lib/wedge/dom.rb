class Wedge
  class DOM
    include Methods

    attr_accessor :dom, :raw_html

    class << self
      # Shortcut for creating dom
      # @param html [String]
      # @return dom [DOM]
      def [] html
        new html
      end
    end

    def initialize html
      html = '' if html.nil?
      html = html.to_html if html.is_a? HTML::DSL

      @raw_html = html

      if server?
        @dom = raw_html.is_a?(String) ? HTML[raw_html.dup] : raw_html
      else
        @dom = raw_html.is_a?(String) ? Element[raw_html.dup] : raw_html
      end
    end

    def find string, &block
      if client?
        node = Wedge::DOM.new dom.find(string)
      elsif server?
        node = Wedge::DOM.new dom.css(string)
      end

      if block_given?
        node.each_with_index do |n, i|
          block.call Wedge::DOM.new(n), i
        end
      end

      node
    end

    unless RUBY_ENGINE == 'opal'
      %w'content inner_html'.each do |meth|
        define_method "#{meth}=" do |cont|
          if node.is_a? Nokogiri::XML::NodeSet
            node.each { |n| n.send("#{meth}=", cont) }
          else
            node.send "#{meth}=", cont
          end
        end
      end

      %w'add_child replace prepend_child'.each do |meth|
        define_method meth do |*args|
          if node.is_a? Nokogiri::XML::NodeSet
            node.each { |n| n.send(meth, *args) }
          else
            node.send(meth, *args)
          end
        end
      end

      def replace_with *args
        if node.is_a? Nokogiri::XML::NodeSet
          node.each { |n| n.replace(*args) }
        else
          node.replace(*args)
        end
      end

      def []= key, value
        if node.is_a? Nokogiri::XML::NodeSet
          node.each { |n| n[key] = value }
        else
          node[key] = value
        end
      end

      def << d
        if node.is_a? Nokogiri::XML::NodeSet
          node.each { |n| n << d }
        else
          node << d
        end
      end

      # def prepend d
      #   if n = node.children.first
      #     n.add_previous_sibling d
      #   else
      #     node << d
      #   end
      # end

      def prepend d
        if node.is_a? Nokogiri::XML::NodeSet
          node.each do |n|
            if nn = n.children.first
              n.add_previous_sibling d
            else
              n << d
            end
          end
        else
          if n = node.children.first
            n.add_previous_sibling d
          else
            node << d
          end
        end
      end

      def append d
        if node.is_a? Nokogiri::XML::NodeSet
          node.each do |n|
            if nn = n.children.last
              nn.add_next_sibling d
            else
              n << d
            end
          end
        else
          if n = node.children.last
            n.add_next_sibling d
          else
            node.content << d
          end
        end
      end

      def hide
        if node.is_a? Nokogiri::XML::NodeSet
          node.each do |n|
            DOM.new(n).style 'display', 'none'
          end
        else
          node.style 'display', 'none'
        end

        node
      end

      def style *args
        style_object = DOM.new(node).styles

        if args.length == 1
          style_object[args.first]
        else
          style_object[args.first] = args.last
          node['style'] = style_object.map { |k, v| [k, v].join(': ') }.join('; ')
        end
      end

      def styles
        style_array = node['style'].to_s.
          split(';').
          reject { |s| s.strip.empty? }.
          map do |s|
            parts = s.split(':', 2)
            return nil if parts.nil?
            return nil if parts.length != 2
            return nil if parts.any? { |s| s.nil? }
            [parts[0].strip, parts[1].strip]
          end.
          reject { |s| s.empty? }
        style_object = {}
        style_array.each { |key, value| style_object[key] = value }

        style_object
      end

      def data key = false, value = false
        d = Hash[node.xpath("@*[starts-with(name(), 'data-')]").map{|a| [a.name, a.value]}]

        if !key
          d
        elsif key && !value
          d[key]
        else
          key = "data-#{key}"

          if node.is_a? Nokogiri::XML::NodeSet
            node.each { |n| n[key] = value }
          else
            node[key] = value
          end
        end
      end

      def val value
        if node.is_a? Nokogiri::XML::NodeSet
          node.each { |n| n.content = value }
        else
          node.content = value
        end
      end

      def add_class classes
        classes = (classes || '').split ' ' unless classes.is_a? Array
        if node.is_a? Nokogiri::XML::NodeSet
          node.each do |n|
            new_classes =  ((n.attr('class') || '').split(' ') << classes).uniq.join(' ')
            n['class'] = new_classes
          end
        else
          new_classes =  ((node.attr('class') || '').split(' ') << classes).uniq.join(' ')
          node['class'] = new_classes
        end
      end

      def remove_class classes
        classes = (classes || '').split ' ' unless classes.is_a? Array

        if node.is_a? Nokogiri::XML::NodeSet
          node.each { |n| n['class'] = (n.attr('class') || '').split(' ').reject { |c| classes.include? c }.join(' ') }
        else
          node['class'] = (node.attr('class') || '').split(' ').reject { |c| classes.include? c }.join(' ')
        end
      end

      def attr key, value = false
        if value
          value = value.join ' ' if value.is_a? Array
          if node.is_a? Nokogiri::XML::NodeSet
            node.each { |n| n[key] = value }
          else
            node[key] = value
          end
        else
          super key
        end
      end
    end

    def html= content
      if server?
        # if the value is nil nokogiri will not update the dom
        content = '' if content.nil?

        if node.is_a? Nokogiri::XML::NodeSet
          node.each { |n| n.inner_html = content }
        else
          node.inner_html = content
        end
      else
        content = content.dom if content.is_a? Wedge::DOM
        node.html content
      end

      node
    rescue
      binding.pry
    end

    if RUBY_ENGINE == 'opal'
      # make it supply the jquery element so it will use that as it doesn't
      # know how to handle the DOM element.
      %w(append prepend replace_with after before).each do |meth|
        define_method meth do |obj|
          obj = obj.dom if obj.is_a? Wedge::DOM
          super obj
        end
      end

      def to_html
        @dom ||= Wedge::DOM.new '<div>'
        el = dom.first
        Wedge::DOM.new('<div>').append(el).html
      end
    end

    def html content = false
      # if the value is nil nokogiri will not update the dom
      content = '' if content.nil?

      if !content
        if server?
          node.inner_html
        else
          node ? node.html : dom.html
        end
      else
        self.html = content
      end
    end

    def node
      @node || dom
    end

    # This allows you to use all the nokogiri or opal jquery methods if a
    # global one isn't set
    def method_missing method, *args, &block
      # respond_to?(symbol, include_all=false)
      if dom.respond_to? method, true
        dom.send method, *args, &block
      else
        super
      end
    end
  end
end
