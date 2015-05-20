require 'spec_helper'
require 'app/components/uploader'

describe Playground::UploaderComponent do
  subject(:uploader) { Wedge[:uploader] }

  html Wedge.html! { button 'Upload' }.to_html

  context '#display' do
    subject { uploader.display }

    if Wedge.server?
      it { is_expected.to be_a Wedge::DOM }
    else
      it { is_expected.to be_nil }
    end
  end

  context 'browser_events' do
    # https://github.com/opal/opal-rspec/issues/20
    # Stubbing doesn't working in opal-rspec so we have to do this
    Wedge::Plugins::Uploader.instance_eval do
      def settings
        { aws_access_key_id: 123456, bucket: 'wedge' }
      end
    end

    before { uploader.trigger :browser_events }

    it 'should have fine uploader button' do
      expect(uploader.dom.find('.qq-uploader').to_html).not_to be_empty
    end
  end if Wedge.client?
end
