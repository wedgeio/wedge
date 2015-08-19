require 'spec_helper'

describe Wedge do
  context 'config' do
    it 'should not have an assets key' do
      expect(Wedge.config.assets_key).to be_nil
    end

    if Wedge.server?
      it 'should return javascript and resource maps', :slow do
        expect(Wedge.javascript).to match /Opal/
        expect(Wedge.source_map).to match /mappings/
      end
    end
  end

  it '#html!' do
    expect(Wedge.html! { button('test') }.to_html).to eq '<button>test</button>'
  end
end
