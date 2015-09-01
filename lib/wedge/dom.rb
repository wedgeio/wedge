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
        if block_given?
          node = Wedge::DOM.new dom.css(string)
        else
          node = Wedge::DOM.new dom.at(string)
        end
      end

      if block_given?
        node.each_with_index do |n, i|
          block.call Wedge::DOM.new(n), i
        end
      end

      node
    end

    unless RUBY_ENGINE == 'opal'
      def prepend d
        if n = node.children.first
          n.add_previous_sibling d
        else
          node << d
        end
      end

      def append d
        if n = node.children.first
      def display el, options = {}, &block
        d = d.dom if d.is_a? Wedge::DOM

        return if el.data 'wedge-popover'

        el.data 'wedge-popover', true
        el = el.to_n

        options = {
          content: 'Loading...',
          position: 'right middle',
          openOn: 'hover'
        }.merge(options)

        options[:classes] = "drop-theme-arrows #{options[:classes]}"

        options = options.to_n

        opts = `$.extend(options, { target: el[0] })`
        drop = Native(`new Drop(opts)`)

        block.call(Native(opts)) if block_given?

        drop
      end

      def ajax el, options = {}, &block
        options = { content: 'loading' }.merge options
        display el, options, &block
      end
          n.add_next_sibling d
        else
          node << d
        end
      end

      def data key = false, value = false
        d = Hash[node.xpath("@*[starts-with(name(), 'data-')]").map{|a| [a.name, a.value]}]

        if !key
          d
        elsif key && !value
          d[key]
        else
          node["data-#{key}"] = value
        end
      end

      def val value
        node.content = value
      end

      def add_class classes
        classes = (classes || '').split ' ' unless classes.is_a? Array
        new_classes =  ((node.attr('class') || '').split(' ') << classes).uniq.join(' ')
        node['class'] = new_classes
      end

      def remove_class classes
        classes = (classes || '').split ' ' unless classes.is_a? Array
        (node.attr('class') || '').split(' ').reject { |n| n =~ /active|asc|desc/i }.join(' ')
      end

      def attr key, value = false
        if value
          value = value.join ' ' if value.is_a? Array
          node[key] = value
        else
          super key
        end
      end
    end

    def html= content
      if server?
        node.inner_html = content
      else
        content = content.dom if content.is_a? Wedge::DOM
        node.html content
      end

      node
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
