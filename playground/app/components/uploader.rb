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

    on :ready do
      wedge_plugin(:uploader).button dom.find("button"), {
        wedge_name: :uploader,
        wedge_method: :add_file,
        key: "playground/uploader/{uuid}.{ext}"
      }
    end
  end
end
