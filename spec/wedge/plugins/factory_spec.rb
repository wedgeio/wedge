require 'spec_helper'
require 'wedge/plugins/factory'

describe Wedge::Plugins::Factory do
  let(:user_stub) { Wedge[:factory][:user].to_h }

  it 'expects the correct fields returned' do
    expect(user_stub.keys).to include *%w'first_name last_name location'
    expect(user_stub[:location][:address].keys).to include 'line1'
  end

  it 'accepts override params' do
    data = Wedge[:factory][:user, api_key: 123456].to_h
    expect(data.keys).to include 'api_key'
  end
end
