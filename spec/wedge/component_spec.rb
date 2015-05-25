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

  def foo
    'bar'
  end
end

describe Wedge::Component do
  subject(:comp) { Wedge[:comp] }

  it 'should respond to foo' do
    expect(subject.foo).to eq 'bar'
  end

  if Wedge.server?
    it 'should set/get templates' do
      expect(subject.tmpl(:foo).to_html).to eq '<button>bar</button>'
    end

    it 'should return html with opal js' do
      expect(subject.to_js(:foo)).to match /Opal/
    end
  end
end
