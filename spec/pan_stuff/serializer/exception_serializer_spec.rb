# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PanStuff::Serializer::ExceptionSerializer do
  let(:status) { 422 }
  let(:error) { 'Example message' }
  let(:exception) { StandardError.new }

  let(:result) do
    JSON.generate({
      validationResponse: {
        status:    status,
        error:     error,
        exception: exception,
      },
    }.stringify_keys)
  end

  let(:result_root_false) do
    JSON.generate({
      status:    status,
      error:     error,
      exception: exception,
    }.stringify_keys)
  end

  describe '#as_json' do
    context 'with root true' do
      let(:serializer) { described_class.new(status: status, error: error, exception: exception) }

      it { expect(serializer.as_json).to eq(result) }
    end

    context 'with root false' do
      let(:serializer) { described_class.new(status: status, error: error, exception: exception, root: false) }

      it { expect(serializer.as_json).to eq(result_root_false) }
    end
  end
end
