require 'spec_helper'
require 'components/layout'

describe Playground::LayoutComponent do
  subject(:layout) { Wedge[:layout] }

  context '#display' do
    subject { layout.display }

    if Wedge.server?
      it { is_expected.to be_a Wedge::DOM }
    else
      it { is_expected.to be_nil }
    end
  end
end
