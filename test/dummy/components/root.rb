require 'wedge/plugins/pjax'
require 'wedge/plugins/form'

require_relative 'base'
require_relative 'bar'
require_relative '../forms/foo'

class DummyApp
  class RootComponent < BaseComponent
    name :root
    html "<div id='foo'>bar</div>"

    def display
      if server?
        wedge(:layout).display do
          dom.to_html
        end
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
