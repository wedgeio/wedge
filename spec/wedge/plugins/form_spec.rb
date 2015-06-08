require 'spec_helper'
require 'wedge/plugins/form'

class TestForm < Wedge::Plugins::Form
  name :test_form

  attr_reader :id, type: Integer, default: '1'
  attr_reader :type, type: Symbol, default: -> { id == 1 ? 'admin' : 'user' }
  attr_reader :zipcode

  attr_accessor :first_name, :last_name
  attr_accessor :phone_number, type: Integer

  form_accessor :car

  def validate
    assert_present %w'first_name last_name car'
    assert_numeric :phone_number
  end

  def full_name
    "#{first_name} #{last_name}"
  end

  def phone_number= number
    super(number.gsub(/[^\d]/, ''))
  end

  def default_zipcode
    55555
  end
end

class CarForm < Wedge::Plugins::Form
  name :car_form

  attr_reader :id, default: 1
  attr_accessor :make, :model, :vin, :year

  def validate
    assert_present %w'make model vin year'
    assert_length :vin, 17
  end

  def default_year
    Time.now.year
  end
end

describe Wedge::Plugins::Form do
  let(:params) {{
    first_name: 'CJ', last_name: 'Lazell', phone_number: '(555) 555 - 5555',
    car: {
      make: 'ford', model: 'focus', vin: '12121212121212121'
    }
  }}
  subject(:test_form) { Wedge[:test_form, params] }

  context 'attributes' do
    subject(:attributes) { test_form.attributes }

    it { is_expected.to include({
      id: 1, first_name: 'CJ', last_name: 'Lazell', phone_number: 5555555555, zipcode: 55555
    })}
    it { is_expected.not_to have_key :full_name }
  end

  context 'validation errors' do
    subject { form = Wedge[:test_form]; form.valid?; form.errors }

    it { is_expected.to include({
      first_name: [:not_present], last_name: [:not_present],
      :car => {
        make: [:not_present], model: [:not_present], vin: [:not_present, :not_in_range]
      }
    }) }

    it { is_expected.not_to include phone_number: :not_numeric }
  end
end
