class DummyApp
  class BarComponent < Wedge::Component
    config.name :bar
    config.requires :root, :base

    def moo
      'cow'
    end

    on :clicked_foo, for: :root do
      dom.find('body').append moo
    end
  end
end
