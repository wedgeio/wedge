require_relative 'test_helper'

class TestBrowserIO < Minitest::Test
  def test_javascript
    assert BrowserIO.javascript[/Opal/]
  end
end
