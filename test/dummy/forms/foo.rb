class DummyApp
  class FooForm < BrowserIO::Plugins::Form
    config.name :foo_form
    config.requires :bar_form
  end
end
