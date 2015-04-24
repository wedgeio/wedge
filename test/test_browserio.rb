require 'phantomjs'
require_relative 'test_helper'

class Testwedge < Minitest::Test
  def test_javascript_and_source_maps
    assert wedge.javascript[/Opal/]
    assert wedge.source_map[/mappings/]
  end

  # def test_moo
  #   Phantomjs.run('./test/test.js')
  # end
end
