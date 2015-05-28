require 'spec_helper'
require 'components/uploader'

describe 'auth' do
  context 'errors' do
    if Wedge.server?
      it 'to return wrong username or password' do
        expect(Wedge[:auth].login_user({})[:errors]).to match /wrong username or password/i
      end
    else
      puts Wedge[:uploader].config.data.to_h
      puts Wedge.config.data.to_h
      puts Wedge.events.events
    end
  end
  # subject(:uploader) { Wedge[:uploader] }
  #
  # html Wedge.html! { button 'Upload' }.to_html
  #
  # context '#display' do
  #   subject { uploader.display }
  #
  #   if Wedge.server?
  #     it { is_expected.to be_a Wedge::DOM }
  #   else
  #     it { is_expected.to be_nil }
  #   end
  # end
  #
  # context 'browser_events' do
  #   before do
  #     allow_any_instance_of(Wedge::Plugins::Uploader).to receive(:settings).and_return({
  #       aws_access_key_id: 123456,
  #       bucket: 'wedge'
  #     })
  #     puts Wedge.events.events
  #     uploader.trigger :browser_events
  #   end
  #
  #   it 'should have fine uploader button' do
  #     expect(uploader.dom.find('.qq-uploader').to_html).not_to be_empty
  #   end
  # end if Wedge.client?
end
