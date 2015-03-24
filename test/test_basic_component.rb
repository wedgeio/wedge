require_relative 'test_helper'

class BasicComponent < BrowserIO::Component
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
    assert_equal 'bar', bio(:basic).foo
  end

  def test_parsing_html
    assert_equal '<div id="foo">bar</div>', bio(:basic).tmpl(:foo).to_html
  end

  def test_returning_js
    ap bio(:basic, :render_js).foo
    assert bio(:basic, :render_js).foo[/opal/]
  end
end
