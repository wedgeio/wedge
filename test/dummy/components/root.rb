require_relative 'base' unless RUBY_ENGINE == 'opal'

class DummyApp
  class RootComponent < BaseComponent
    config.name :root
    config.requires :base, :bar, :foo_form, :pjax_plugin
    config.html "<div id='foo'>bar</div>"

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
