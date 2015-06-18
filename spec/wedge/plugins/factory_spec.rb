require 'spec_helper'
require 'wedge/plugins/factory'

describe Wedge::Plugins::Factory do
  let(:user_stub) { Wedge[:factory][:user] }

  it 'expects the correct fields returned' do
    expect(user_stub.keys).to include *%w'first_name last_name location'
    expect(user_stub[:location][:address].keys).to include 'line1'
  end
end
