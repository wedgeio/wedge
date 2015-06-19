require 'spec_helper'
require 'wedge/plugins/form'

class TestForm < Wedge::Plugins::Form
  name :test_form

  attr_reader :id, type: Integer, default: '1'
  attr_reader :type, type: Symbol, default: -> { id == 1 ? 'admin' : 'user' }
  attr_reader :zipcode

  attr_accessor :first_name, :last_name
  attr_accessor :phone_number, type: Integer
  attr_accessor :user_only, default: true, unless: -> { current_user.admin? }
  attr_accessor :email, hidden: true

  model_alias :phone_num, :phone_number

  form_accessor :car

  def validate
    assert_present %w'first_name last_name'
    assert_numeric :phone_number
    assert_form :car
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

class TestLimitForm < TestForm
  name :test_limit_form
  form_accessor :car, atts: %w'make model'
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
    id: 5, first_name: 'CJ', last_name: 'Lazell', phone_number: '(555) 555 - 5555',
    car: {
      make: 'ford', model: 'focus', vin: '12121212121212121'
    }
  }}
  subject(:test_form) { Wedge[:test_form, params] }

  context 'attributes' do
    subject(:attributes) { test_form.attributes }

    # id is 1 because values that are attr_readers can't be set via passed in
    # params, this stops people updating values they shouldn't and is why you
    # should always use a form to filter param data before passing it to a model.
    it { is_expected.to include({
      id: 1, first_name: 'CJ', last_name: 'Lazell', phone_number: 5555555555, zipcode: 55555
    })}
    it { is_expected.not_to have_key :full_name }
    it { is_expected.not_to have_key :email }
  end

  context 'model_attributes' do
    subject(:attributes) { test_form.model_attributes }

    it { is_expected.not_to have_key :phone_number }
    it { is_expected.to have_key :phone_num }
  end

  context 'validation errors' do
    subject { form = Wedge[:test_form]; form.valid?; form.errors }

    it { is_expected.to include({
      first_name: [:not_present], last_name: [:not_present],
      :car => {
        make: [:not_present], model: [:not_present], vin: [:not_present]
      }
    }) }

    it { is_expected.not_to include phone_number: [:not_numeric] }
  end

  context 'limit form validation' do
    subject { form = Wedge[:test_limit_form]; form.valid?; form.errors }

    it { is_expected.to include({
      :car => {
        make: [:not_present], model: [:not_present]
      }
    })}

    it { is_expected.not_to include vin: [:not_present] }
  end

  context 'block#current_user' do
    it 'should not have access to user_only' do
      expect(test_form.user_only).to be_nil
    end
  end
end
