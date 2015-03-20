require_relative 'test_helper'

class BasicComponent < BrowserIO::Component
  setup do |config|
    config.name :basic
  end

  def foo
    'bar'
  end
end

class TestComponent < Minitest::Test
  def test_calling_basic_component
    assert_equal 'bar', bio(:basic).foo
  end
end
