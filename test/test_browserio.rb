require 'phantomjs'
require_relative 'test_helper'

class TestBrowserIO < Minitest::Test
  def test_javascript_and_source_maps
    assert BrowserIO.javascript[/Opal/]
    assert BrowserIO.source_map[/mappings/]
  end

  # def test_moo
  #   Phantomjs.run('./test/test.js')
  # end
end
