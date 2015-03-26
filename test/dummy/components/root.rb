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
    config.requires :bar

    def initialize
      events = opts.events
      # `console.log(events)`
    end if client?

    def display
      if server?
        dom
      else
        el = Element['<div>']
        el.html 'foo'
        dom.find('#foo').before el
      end
    end

    on :ready do
      puts 'dom ready'
    end

    on :click, '#foo' do |el|
      el.after '<div>bar</div>'
      trigger :clicked_foo
    end
  end
end
