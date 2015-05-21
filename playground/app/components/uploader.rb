require_relative 'layout'
require 'wedge/plugins/uploader'

class Playground
  class UploaderComponent < Wedge::Component
    name :uploader
    html 'public/uploader.html' do
      set_dom dom.find('body').html
    end

    def initialize
      store[:foo] = 'bar' if server?
    end

    def display
      # todo: make a test for this:
      puts html! {
        if foo = store[:foo]
          div foo
        end
      }.to_html
      wedge(:layout).display { dom }
    end

    def add_file data = {}
      if server?
        puts 'uploaded to s3'
      else
        puts 'uploaded to s3'
      end
    end

    on :ready do
      puts store[:foo]
      button = dom.find("button")
      button.hide
      wedge_plugin(:uploader).button button, {
        wedge_name: :uploader,
        wedge_method: :add_file
      }
    end
  end
end
