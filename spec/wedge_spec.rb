require 'spec_helper'
require 'wedge'

describe Wedge do
  context 'config' do
    if Wedge.server?
      it 'should have an assets key' do
        expect(Wedge.config.assets_key).not_to be_nil
      end
    else
      it 'should not have an assets key' do
        expect(Wedge.config.assets_key).to be_nil
      end
    end
  end

  it '#html!' do
    expect(Wedge.html! { button('test') }.to_html).to eq '<button>test</button>'
  end
end
