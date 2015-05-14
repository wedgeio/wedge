class DummyApp
  class LayoutComponent < Wedge::Component
    name :layout
    html <<-HTML
      <!DOCTYPE html>
      <html>
        <head>
          <script src="//code.jquery.com/jquery-1.11.2.js"></script>
          #{Wedge.script_tag}
        </head>
        <body>
        </body>
      </html>
    HTML
    dom do
      dom.find('body') << assets(:js)
    end

    def display &block
      return unless server?

      dom.find('body').add_child block.call
      dom
    end
  end
end
