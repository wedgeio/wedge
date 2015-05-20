require 'spec_helper'
require 'app/components/layout'

describe 'Layout Component' do
  it 'should have #display' do
    display = Wedge[:layout].display

    if Wedge.server?
      expect(display).to be_a Wedge::DOM
    else
      expect(display).to be_nil
    end
  end
end
