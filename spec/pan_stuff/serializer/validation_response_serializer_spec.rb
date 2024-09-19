# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PanStuff::Serializer::ValidationResponseSerializer do
  let(:model) do
    PanStuff::Serializer::ValidationResponse.new({ id: 'myId', status: 422, message: 'Example message' })
  end

  let(:result) do
    JSON.generate({
                    validationResponse: {
                      id:      model.id,
                      status:  model.status,
                      message: model.message,
                    },
                  })
  end

  describe '#as_json' do
    let(:serializer) { described_class.new(model) }

    it { expect(serializer.as_json).to eq(result) }
  end
end
