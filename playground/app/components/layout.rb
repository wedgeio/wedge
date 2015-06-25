class Playground
  class LayoutComponent < Wedge::Component
    name :layout
    html 'public/index.html' do
      head = dom.find('head')
      html = dom.find('html')

      inline_tags = []

      head.css('script, link').each do |tag|
        if (%w(src href) & tag.attributes.keys).empty?
          inline_tags << tag
        end
        tag.remove
      end

      head.add_child assets [:css, :default]
      html.add_child assets [:js, :default]
      html.add_child Wedge.script_tag

      inline_tags.each do |tag|
        html.add_child tag
      end

      # Clear out the body
      dom.find('body').html ''
    end

    def display options = {}, &block
      return unless server?

      begin; dom.find('head').add_child csrf_metatag; rescue; end
      body_dom = dom.find('body')
      body_dom << block.call if block_given?

      dom
    end
  end
end
