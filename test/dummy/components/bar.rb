require_relative 'root' unless RUBY_ENGINE == 'opal'

class DummyApp
  class BarComponent < BrowserIO::Component
    config.name :bar
    config.requires :root

    def moo
      'cow'
    end

    on :clicked_foo, for: :root do
      dom.find('body').append moo
    end
  end
end
