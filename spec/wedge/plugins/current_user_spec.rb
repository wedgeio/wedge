require 'spec_helper'
require 'wedge/plugins/current_user'

class TestAbilities < Wedge::Plugins::AbilityList
  name :ability_list

  def initialize user
    if user.admin?
      can :view, :admin
    end
  end
end

class CurrentUser < Wedge::Plugins::CurrentUser
  name :current_user

  attr_reader :id, :is_admin, :secret_key
  attr_accessor :first_name, :last_name

  def admin?
    is_admin
  end
end

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

    if Wedge.server?
      it 'expects secret_key' do
        expect(current_user.secret_key).to eq 123456
      end
    else
      it 'expects NO secret_key' do
        expect(current_user.secret_key).to eq nil
      end
    end
  end
end
