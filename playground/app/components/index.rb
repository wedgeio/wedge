require_relative 'layout'

class Playground
  class IndexComponent < Wedge::Component
    name :index
    html 'public/index.html' do
      set_dom dom.find('body').html
    end

    def display
      wedge(:layout).display { dom }
    end
  end
end
