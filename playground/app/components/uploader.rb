require_relative 'layout'
require 'wedge/plugins/uploader'

class Playground
  class UploaderComponent < Wedge::Component
    name :uploader
    html 'public/uploader.html' do
      set_dom dom.find('body').html
    end

    def display
      wedge(:layout).display { dom }
    end

    def add_file data = {}
      if server?
        puts 'uploaded to s3'
      else
        puts 'uploaded to s3'
      end
    end

    on :testing do
      puts 'test'
    end

    on :ready do
      button = dom.find("button")
      button.hide
      wedge_plugin(:uploader).button button, {
        wedge_name: :uploader,
        wedge_method: :add_file
      }
    end
  end
end
