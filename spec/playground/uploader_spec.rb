require 'spec_helper'
require 'app/components/uploader'

describe Playground::UploaderComponent do
  subject(:uploader) { Wedge[:uploader] }

  html Wedge.html! { button 'Upload' }

  context '#display' do
    subject { uploader.display }

    if Wedge.server?
      it { is_expected.to be_a Wedge::DOM }
    else
      it { is_expected.to be_nil }
    end
  end

  context 'browser_events' do
    before do
      # stub store settings
      Wedge::Plugins::Uploader.any_instance.stub(:settings).and_return({
        aws_access_key_id: 123456,
        bucket: 'wedge'
      })
      uploader.trigger :browser_events
    end

    it 'should' do
      puts 'here'
    end
  end if Wedge.client?
end
