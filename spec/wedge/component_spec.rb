require 'spec_helper'
require 'wedge/component'

class Comp < Wedge::Component
  name :comp
  html (html! {
    html do
      body do
        button 'bar'
      end
    end
  }.to_html) do
    tmpl :foo, dom.find('button')
  end
end

describe Wedge::Component do
  let(:comp) { Wedge[:comp] }

  if Wedge.server?
    it 'should set templates' do
      expect(comp.tmpl(:foo).to_html).to eq '<button>bar</button>'
    end
  end
end
