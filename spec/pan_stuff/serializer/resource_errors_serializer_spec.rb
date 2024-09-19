# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PanStuff::Serializer::ResourceErrorsSerializer do
  before do
    stub_const('ErrorClass', error_class)
    stub_const('ModelWithErrors', model_with_errors)
  end

  let(:error_class) do
    Class.new do
      def full_messages
        ['Password cant be blank']
      end

      def details
        { password: [{ error: :too_short, count: 3 }] }
      end
    end
  end

  let(:model_with_errors) do
    Class.new do
      def errors
        ErrorClass.new
      end
    end
  end

  describe '#as_json' do
    let(:resource_with_errors) { model_with_errors.new }
    let(:resource_error_serializer_instance) { described_class.new(resource_with_errors.errors) }
    let(:expected_error_json) do
      '{"errors":["Password cant be blank"],"details":{"password":[{"error":"tooShort","count":3}]}}'
    end

    it 'serialize active record resource errors' do
      expect(resource_error_serializer_instance.as_json).to eq(expected_error_json)
    end
  end
end
