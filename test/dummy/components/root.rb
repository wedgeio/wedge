require_relative 'layout'
require_relative 'base'
require_relative 'bar'
require_relative '../forms/foo'

class DummyApp
  class RootComponent < BaseComponent
    name :root
    html html! {
      div 'bar', id: 'foo'
    }

    def display
      if server?
        wedge(:layout).display do
          dom.to_html
        end
      else
        html! do
          div class: 'control-group fake optional' do
            label 'Profile Picture', class: 'fake optional control-label'
            div id: 'profile_picture'
          end
        end
        dom.find('#foo').before html! {
          div 'foo'
        }
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
