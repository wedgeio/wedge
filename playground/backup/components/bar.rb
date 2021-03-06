require_relative 'root'

class DummyApp
  class BarComponent < Wedge::Component
    name :bar

    def moo
      'cow'
    end

    on :ready do
      puts 'bar ready'
    end

    on :clicked_foo, for: :root do
      dom.find('body').append moo
    end
  end
end
