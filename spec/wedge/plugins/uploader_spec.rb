require 'spec_helper'
require 'wedge/plugins/uploader'

describe Wedge::Plugins::Uploader do
  before do
    allow(Wedge.config).to receive(:settings).and_return(
      uploader: {
        aws_access_key_id: 123456,
        aws_secret_access_key: 654321,
        bucket: 'wedge'
      }
    )
  end

  subject(:uploader) { Wedge[:uploader_plugin] }

  context 'store#settings' do
    it 'should have the correct settings' do
      settings = uploader.config.store[:settings]

      if Wedge.server?
        expect(settings.keys).to include *%w'aws_access_key_id aws_secret_access_key bucket'
      else
        expect(settings.keys).not_to include *%w'aws_secret_access_key'
      end
    end
  end
end
