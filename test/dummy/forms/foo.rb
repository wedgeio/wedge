class DummyApp
  class FooForm < Wedge::Plugins::Form
    config.name :foo_form
    config.requires :bar_form
  end
end
