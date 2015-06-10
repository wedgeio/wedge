require 'spec_helper'
require 'wedge/plugins/current_user'

class TestComponent < Wedge::Component
  name :test

  def display
    if current_user.can? :view, :admin
      'admin'
    else
      'user'
    end
  end
end

describe Wedge::Plugins::CurrentUser do
  let(:test_comp) { Wedge[:test] }
  let(:current_user) { Wedge[:current_user] }

  context 'admin' do
    it 'expects to be an admin' do
      expect(test_comp.display).to eq 'admin'
    end

    it 'secret_key' do
      expect(current_user.secret_key).to eq(Wedge.server?? 123456 : nil)
    end
  end
end
