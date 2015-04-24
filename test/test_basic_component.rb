require_relative 'test_helper'

class BasicComponent < wedge::Component
  config.name :basic
  config.html <<-HTML
    <!DOCTYPE html>
    <html>
      <body>
        <div id='foo'>bar</div>
      </body>
    </html>
  HTML
  config.dom do
    tmpl :foo, dom.find('#foo')
  end

  def foo
    'bar'
  end
end

class TestComponent < Minitest::Test
  def test_calling_basic_component
    assert_equal 'bar', wedge(:basic).foo
  end

  def test_parsing_html
    assert_equal '<div id="foo">bar</div>', wedge(:basic).tmpl(:foo).to_html
  end

  def test_returning_js
    assert wedge(:basic, :js).foo[/Opal/]
  end
end
