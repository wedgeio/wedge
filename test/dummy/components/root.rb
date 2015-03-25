class DummyApp
  class RootComponent < BrowserIO::Component
    config.name :root
    config.html <<-HTML
      <!DOCTYPE html>
      <html>
        <head>
          <script src="//code.jquery.com/jquery-1.11.2.js"></script>
        </head>
        <body>
          <div id='foo'>bar</div>
        </body>
      </html>
    HTML
    config.dom do
      dom.find('body') << assets(:js)
    end

    def display
      if server?
        dom
      else
        el = Element['<div>']
        el.html 'foo'
        dom.find('#foo').before el
      end
    end
  end
end
